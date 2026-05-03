import assert from 'node:assert/strict';
import { once } from 'node:events';
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import os from 'node:os';
import { join } from 'node:path';
import { test } from 'node:test';

import {
  createAnthropicProxyServer,
  createModelList,
  parseModelIds,
} from '../src/proxy.js';
import {
  createDefaultGatewayConfig,
  createFileBackedConfigStore,
  createInMemoryConfigStore,
  getActiveProvider,
  normalizeGatewayConfig,
} from '../src/config.js';

async function withServer(options, run) {
  const server = createAnthropicProxyServer(options);
  server.listen(0, '127.0.0.1');
  await once(server, 'listening');
  const address = server.address();
  const baseUrl = `http://127.0.0.1:${address.port}`;

  try {
    await run(baseUrl);
  } finally {
    server.close();
    await once(server, 'close');
  }
}

function createConfigStore(config = {}) {
  return createInMemoryConfigStore({
    providers: [
      {
        id: 'deepseek',
        name: 'DeepSeek',
        baseUrl: 'https://api.deepseek.com/anthropic',
        apiKey: '',
        useFakeModels: true,
        fakeModels: ['deepseek-v4-pro', 'deepseek-v4-flash'],
      },
    ],
    activeProviderId: 'deepseek',
    ...config,
  });
}

test('parseModelIds trims whitespace and removes empty entries', () => {
  assert.deepEqual(parseModelIds(' deepseek-v4-pro, ,deepseek-v4-flash '), [
    'deepseek-v4-pro',
    'deepseek-v4-flash',
  ]);
});

test('createModelList returns an Anthropic-style models payload', () => {
  assert.deepEqual(createModelList(['deepseek-v4-pro']), {
    data: [
      {
        id: 'deepseek-v4-pro',
        type: 'model',
        display_name: 'deepseek-v4-pro',
      },
    ],
    first_id: 'deepseek-v4-pro',
    has_more: false,
    last_id: 'deepseek-v4-pro',
  });
});

test('normalizeGatewayConfig preserves an explicitly empty fake model list', () => {
  const config = normalizeGatewayConfig({
    activeProviderId: 'custom',
    providers: [
      {
        id: 'custom',
        name: 'Custom',
        baseUrl: 'https://gateway.example/anthropic',
        apiKey: '',
        useFakeModels: true,
        fakeModels: [],
      },
    ],
  });

  assert.deepEqual(config.providers[0].fakeModels, []);
});

test('normalizeGatewayConfig accepts legacy single-provider options', () => {
  const config = normalizeGatewayConfig({
    upstreamBaseUrl: 'https://gateway.example/anthropic/',
    apiKey: 'legacy-key',
    models: ['custom-model'],
  });

  assert.equal(config.providers[0].id, 'legacy');
  assert.equal(config.providers[0].baseUrl, 'https://gateway.example/anthropic');
  assert.equal(config.providers[0].apiKey, 'legacy-key');
  assert.deepEqual(config.providers[0].fakeModels, ['custom-model']);
});

test('createDefaultGatewayConfig uses environment defaults', () => {
  const config = createDefaultGatewayConfig({
    HOST: '127.0.0.2',
    PORT: '9999',
    DEEPSEEK_ANTHROPIC_BASE_URL: 'https://example.com/anthropic/',
    DEEPSEEK_MODELS: 'alpha,beta',
  });

  assert.equal(config.host, '127.0.0.2');
  assert.equal(config.port, 9999);
  assert.equal(config.providers[0].baseUrl, 'https://example.com/anthropic');
  assert.deepEqual(config.providers[0].fakeModels, ['alpha', 'beta']);
});

test('getActiveProvider falls back to the first provider when the active id is missing', () => {
  const provider = getActiveProvider({
    activeProviderId: 'missing',
    providers: [
      {
        id: 'first',
        name: 'First',
        baseUrl: 'https://first.example/anthropic',
        apiKey: '',
        useFakeModels: false,
        fakeModels: [],
      },
    ],
  });

  assert.equal(provider.id, 'first');
});

test('file-backed config store persists normalized updates and tolerates invalid JSON', () => {
  const tempDir = mkdtempSync(join(os.tmpdir(), 'claude-gateway-test-'));
  const configPath = join(tempDir, 'config.json');

  try {
    const store = createFileBackedConfigStore({
      configPath,
      env: {
        HOST: '127.0.0.1',
        PORT: '8787',
        DEEPSEEK_ANTHROPIC_BASE_URL: 'https://api.deepseek.com/anthropic',
        DEEPSEEK_MODELS: 'deepseek-v4-pro,deepseek-v4-flash',
      },
    });

    const initial = store.getConfig();
    assert.equal(initial.activeProviderId, 'deepseek');

    const saved = store.setConfig({
      host: '127.0.0.1',
      port: 8787,
      activeProviderId: 'custom-provider',
      providers: [
        {
          id: 'Custom Provider',
          name: 'Custom Provider',
          baseUrl: 'https://gateway.example/anthropic/',
          apiKey: '',
          useFakeModels: false,
          fakeModels: [],
        },
      ],
    });

    assert.equal(saved.activeProviderId, 'custom-provider');
    assert.equal(saved.providers[0].id, 'custom-provider');
    assert.equal(saved.providers[0].baseUrl, 'https://gateway.example/anthropic');

    const persisted = JSON.parse(readFileSync(configPath, 'utf8'));
    assert.equal(persisted.activeProviderId, 'custom-provider');

    writeFileSync(configPath, '{ invalid json', 'utf8');
    const recovered = store.getConfig();
    assert.equal(recovered.activeProviderId, 'custom-provider');
  } finally {
    rmSync(tempDir, { recursive: true, force: true });
  }
});

test('GET /v1/models returns the configured fake model list', async () => {
  await withServer({ configStore: createConfigStore() }, async (baseUrl) => {
    const response = await fetch(`${baseUrl}/v1/models`);
    const body = await response.json();

    assert.equal(response.status, 200);
    assert.equal(response.headers.get('content-type'), 'application/json');
    assert.deepEqual(body.data.map((model) => model.id), [
      'deepseek-v4-pro',
      'deepseek-v4-flash',
    ]);
  });
});

test('GET /v1/models/:id returns one configured model', async () => {
  await withServer({ configStore: createConfigStore() }, async (baseUrl) => {
    const response = await fetch(`${baseUrl}/v1/models/deepseek-v4-pro`);
    const body = await response.json();

    assert.equal(response.status, 200);
    assert.deepEqual(body, {
      id: 'deepseek-v4-pro',
      type: 'model',
      display_name: 'deepseek-v4-pro',
    });
  });
});

test('GET /v1/models forwards upstream when fake models are disabled', async () => {
  const fetchCalls = [];
  const fetchImpl = async (url, init) => {
    fetchCalls.push({ url, init });
    return new Response(JSON.stringify({ data: [{ id: 'claude-sonnet-4-5', type: 'model' }] }), {
      status: 200,
      headers: { 'content-type': 'application/json' },
    });
  };

  await withServer(
    {
      fetchImpl,
      configStore: createConfigStore({
        providers: [
          {
            id: 'anthropic',
            name: 'Anthropic',
            baseUrl: 'https://api.anthropic.example',
            apiKey: 'stored-key',
            useFakeModels: false,
            fakeModels: [],
          },
        ],
        activeProviderId: 'anthropic',
      }),
    },
    async (baseUrl) => {
      const response = await fetch(`${baseUrl}/v1/models`);
      const body = await response.json();

      assert.equal(response.status, 200);
      assert.deepEqual(body, { data: [{ id: 'claude-sonnet-4-5', type: 'model' }] });
      assert.equal(fetchCalls.length, 1);
      assert.equal(fetchCalls[0].url, 'https://api.anthropic.example/v1/models');
      assert.equal(fetchCalls[0].init.method, 'GET');
      assert.equal(fetchCalls[0].init.headers.authorization, 'Bearer stored-key');
    },
  );
});

test('GET /v1/models/:id forwards upstream when fake models are disabled', async () => {
  const fetchCalls = [];
  const fetchImpl = async (url, init) => {
    fetchCalls.push({ url, init });
    return new Response(JSON.stringify({ id: 'claude-sonnet-4-5', type: 'model' }), {
      status: 200,
      headers: { 'content-type': 'application/json' },
    });
  };

  await withServer(
    {
      fetchImpl,
      configStore: createConfigStore({
        providers: [
          {
            id: 'anthropic',
            name: 'Anthropic',
            baseUrl: 'https://api.anthropic.example',
            apiKey: '',
            useFakeModels: false,
            fakeModels: [],
          },
        ],
        activeProviderId: 'anthropic',
      }),
    },
    async (baseUrl) => {
      const response = await fetch(`${baseUrl}/v1/models/claude-sonnet-4-5`, {
        headers: {
          authorization: 'Bearer desktop-key',
        },
      });
      const body = await response.json();

      assert.equal(response.status, 200);
      assert.deepEqual(body, { id: 'claude-sonnet-4-5', type: 'model' });
      assert.equal(fetchCalls[0].url, 'https://api.anthropic.example/v1/models/claude-sonnet-4-5');
      assert.equal(fetchCalls[0].init.headers.authorization, 'Bearer desktop-key');
    },
  );
});

test('POST /v1/messages forwards the request to the active provider and prefers stored API key', async () => {
  const fetchCalls = [];
  const fetchImpl = async (url, init) => {
    fetchCalls.push({ url, init });
    return new Response(JSON.stringify({ id: 'msg_123', type: 'message' }), {
      status: 200,
      headers: { 'content-type': 'application/json' },
    });
  };

  await withServer(
    {
      fetchImpl,
      configStore: createConfigStore({
        providers: [
          {
            id: 'deepseek',
            name: 'DeepSeek',
            baseUrl: 'https://api.deepseek.com/anthropic',
            apiKey: 'stored-key',
            useFakeModels: true,
            fakeModels: ['deepseek-v4-pro'],
          },
        ],
      }),
    },
    async (baseUrl) => {
      const response = await fetch(`${baseUrl}/v1/messages`, {
        method: 'POST',
        headers: {
          authorization: 'Bearer desktop-key',
          'content-type': 'application/json',
          'anthropic-version': '2023-06-01',
        },
        body: JSON.stringify({ model: 'deepseek-v4-pro', max_tokens: 64, messages: [] }),
      });
      const body = await response.json();

      assert.equal(response.status, 200);
      assert.deepEqual(body, { id: 'msg_123', type: 'message' });
      assert.equal(fetchCalls[0].url, 'https://api.deepseek.com/anthropic/v1/messages');
      assert.equal(fetchCalls[0].init.headers.authorization, 'Bearer stored-key');
      assert.equal(fetchCalls[0].init.headers['anthropic-version'], '2023-06-01');
      assert.equal(
        fetchCalls[0].init.body.toString('utf8'),
        JSON.stringify({ model: 'deepseek-v4-pro', max_tokens: 64, messages: [] }),
      );
    },
  );
});

test('POST /v1/messages sub-routes are forwarded with query strings', async () => {
  const fetchCalls = [];
  const fetchImpl = async (url, init) => {
    fetchCalls.push({ url, init });
    return new Response('{}', { status: 200, headers: { 'content-type': 'application/json' } });
  };

  await withServer(
    {
      fetchImpl,
      configStore: createConfigStore({
        providers: [
          {
            id: 'deepseek',
            name: 'DeepSeek',
            baseUrl: 'https://api.deepseek.com/anthropic',
            apiKey: 'stored-key',
            useFakeModels: true,
            fakeModels: ['deepseek-v4-pro'],
          },
        ],
      }),
    },
    async (baseUrl) => {
      const response = await fetch(`${baseUrl}/v1/messages/count_tokens?debug=1`, {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: '{}',
      });

      assert.equal(response.status, 200);
      assert.equal(
        fetchCalls[0].url,
        'https://api.deepseek.com/anthropic/v1/messages/count_tokens?debug=1',
      );
    },
  );
});

test('POST /v1/messages can forward Claude Desktop bearer token when no provider key is set', async () => {
  const fetchCalls = [];
  const fetchImpl = async (url, init) => {
    fetchCalls.push({ url, init });
    return new Response('{}', { status: 200, headers: { 'content-type': 'application/json' } });
  };

  await withServer(
    {
      fetchImpl,
      configStore: createConfigStore({
        providers: [
          {
            id: 'deepseek',
            name: 'DeepSeek',
            baseUrl: 'https://api.deepseek.com/anthropic',
            apiKey: '',
            useFakeModels: true,
            fakeModels: ['deepseek-v4-pro'],
          },
        ],
      }),
    },
    async (baseUrl) => {
      const response = await fetch(`${baseUrl}/v1/messages`, {
        method: 'POST',
        headers: {
          authorization: 'Bearer desktop-key',
          'content-type': 'application/json',
        },
        body: '{}',
      });

      assert.equal(response.status, 200);
      assert.equal(fetchCalls[0].init.headers.authorization, 'Bearer desktop-key');
    },
  );
});

test('admin config endpoint updates the active provider configuration', async () => {
  const configStore = createConfigStore();

  await withServer({ configStore }, async (baseUrl) => {
    const configResponse = await fetch(`${baseUrl}/_admin/config`);
    const config = await configResponse.json();

    assert.equal(config.activeProviderId, 'deepseek');

    const response = await fetch(`${baseUrl}/_admin/config`, {
      method: 'PUT',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({
        host: '127.0.0.1',
        port: 8787,
        activeProviderId: 'custom',
        providers: [
          {
            id: 'custom',
            name: 'Custom Anthropic Gateway',
            baseUrl: 'https://gateway.example/anthropic',
            apiKey: 'new-key',
            useFakeModels: false,
            fakeModels: [],
          },
        ],
      }),
    });
    const body = await response.json();

    assert.equal(response.status, 200);
    assert.equal(body.activeProviderId, 'custom');
    assert.equal(body.providers[0].baseUrl, 'https://gateway.example/anthropic');
  });
});

test('admin status endpoint reports the current provider', async () => {
  await withServer({ configStore: createConfigStore() }, async (baseUrl) => {
    const response = await fetch(`${baseUrl}/_admin/status`);
    const body = await response.json();

    assert.equal(response.status, 200);
    assert.equal(body.activeProvider.id, 'deepseek');
    assert.equal(body.activeProvider.useFakeModels, true);
  });
});

test('unsupported routes return 404 JSON', async () => {
  await withServer({ configStore: createConfigStore() }, async (baseUrl) => {
    const response = await fetch(`${baseUrl}/v1/unknown`);
    const body = await response.json();

    assert.equal(response.status, 404);
    assert.equal(body.error.type, 'not_found_error');
  });
});
