import { createServer } from 'node:http';
import { Readable } from 'node:stream';
import {
  createInMemoryConfigStore,
  getActiveProvider,
  parseModelIds,
} from './config.js';

export { DEFAULT_MODELS, DEFAULT_UPSTREAM_BASE_URL, parseModelIds } from './config.js';

const HOP_BY_HOP_HEADERS = new Set([
  'connection',
  'content-length',
  'host',
  'keep-alive',
  'proxy-authenticate',
  'proxy-authorization',
  'te',
  'trailer',
  'transfer-encoding',
  'upgrade',
]);

export function createModelList(models = DEFAULT_MODELS) {
  const data = models.map(createModelRecord);

  return {
    data,
    first_id: data[0]?.id ?? null,
    has_more: false,
    last_id: data.at(-1)?.id ?? null,
  };
}

function createModelRecord(model) {
  return {
    id: model,
    type: 'model',
    display_name: model,
  };
}

function sendJson(response, statusCode, payload) {
  response.writeHead(statusCode, {
    'content-type': 'application/json',
    'cache-control': 'no-store',
  });
  response.end(JSON.stringify(payload));
}

function sendError(response, statusCode, type, message) {
  sendJson(response, statusCode, {
    error: {
      type,
      message,
    },
  });
}

function readRequestBody(request) {
  return new Promise((resolve, reject) => {
    const chunks = [];

    request.on('data', (chunk) => chunks.push(chunk));
    request.on('end', () => resolve(Buffer.concat(chunks)));
    request.on('error', reject);
  });
}

function normalizeHeaderValue(value) {
  if (Array.isArray(value)) {
    return value.join(', ');
  }

  return value;
}

function buildForwardHeaders(requestHeaders, apiKey) {
  const sanitizedHeaders = Object.fromEntries(
    Object.entries(requestHeaders)
      .filter(([name]) => !HOP_BY_HOP_HEADERS.has(name.toLowerCase()))
      .map(([name, value]) => [name.toLowerCase(), normalizeHeaderValue(value)])
      .filter(([, value]) => value !== undefined),
  );

  const incomingAuthorization = sanitizedHeaders.authorization;
  const incomingApiKey = sanitizedHeaders['x-api-key'];
  const resolvedApiKey = apiKey || incomingAuthorization?.replace(/^Bearer\s+/i, '') || incomingApiKey || '';
  const { authorization, 'x-api-key': xApiKey, ...headersWithoutCredentials } = sanitizedHeaders;

  if (!resolvedApiKey) {
    return headersWithoutCredentials;
  }

  return {
    ...headersWithoutCredentials,
    authorization: `Bearer ${resolvedApiKey}`,
    'x-api-key': resolvedApiKey,
  };
}

function copyResponseHeaders(upstreamResponse) {
  return Object.fromEntries(
    [...upstreamResponse.headers.entries()].filter(
      ([name]) => !HOP_BY_HOP_HEADERS.has(name.toLowerCase()),
    ),
  );
}

function createUpstreamUrl(upstreamBaseUrl, path) {
  const baseUrl = upstreamBaseUrl.endsWith('/') ? upstreamBaseUrl.slice(0, -1) : upstreamBaseUrl;
  return `${baseUrl}${path}`;
}

async function forwardUpstreamRequest(request, response, options) {
  const { fetchImpl, provider, pathAndSearch } = options;
  const headers = buildForwardHeaders(request.headers, provider.apiKey);
  const body = request.method === 'GET' || request.method === 'HEAD' ? undefined : await readRequestBody(request);
  const upstreamResponse = await fetchImpl(createUpstreamUrl(provider.baseUrl, pathAndSearch), {
    method: request.method,
    headers,
    body,
  });

  response.writeHead(upstreamResponse.status, copyResponseHeaders(upstreamResponse));

  if (upstreamResponse.body) {
    Readable.fromWeb(upstreamResponse.body).pipe(response);
    return;
  }

  response.end();
}

async function readJsonBody(request) {
  const body = await readRequestBody(request);

  if (body.length === 0) {
    return {};
  }

  return JSON.parse(body.toString('utf8'));
}

function createPublicProviderView(provider) {
  return {
    id: provider.id,
    name: provider.name,
    baseUrl: provider.baseUrl,
    apiKey: provider.apiKey,
    useFakeModels: provider.useFakeModels,
    fakeModels: [...provider.fakeModels],
  };
}

function createStatusPayload(config, configStore) {
  const activeProvider = getActiveProvider(config);

  return {
    ok: true,
    service: 'claude-anthropic-gateway',
    configPath: configStore.configPath ?? null,
    activeProvider: createPublicProviderView(activeProvider),
    host: config.host,
    port: config.port,
  };
}

function createConfigPayload(config) {
  return {
    host: config.host,
    port: config.port,
    activeProviderId: config.activeProviderId,
    providers: config.providers.map(createPublicProviderView),
  };
}

function createDefaultConfigStoreFromLegacyOptions(options) {
  return createInMemoryConfigStore(
    {
      providers: [
        {
          id: 'legacy',
          name: 'Legacy Provider',
          baseUrl: options.upstreamBaseUrl,
          apiKey: options.apiKey ?? '',
          useFakeModels: true,
          fakeModels: options.models ?? parseModelIds(process.env.DEEPSEEK_MODELS),
        },
      ],
      activeProviderId: 'legacy',
    },
    options.env ?? process.env,
  );
}

export function createAnthropicProxyServer(options = {}) {
  const fetchImpl = options.fetchImpl ?? globalThis.fetch;
  const configStore = options.configStore ?? createDefaultConfigStoreFromLegacyOptions(options);

  if (!fetchImpl) {
    throw new Error('This proxy requires Node.js 18+ or a custom fetch implementation.');
  }

  return createServer(async (request, response) => {
    try {
      const requestUrl = new URL(request.url ?? '/', 'http://127.0.0.1');
      const config = configStore.getConfig();
      const activeProvider = getActiveProvider(config);

      if (request.method === 'GET' && requestUrl.pathname === '/') {
        sendJson(response, 200, createStatusPayload(config, configStore));
        return;
      }

      if (request.method === 'GET' && requestUrl.pathname === '/health') {
        sendJson(response, 200, { ok: true, activeProviderId: activeProvider.id });
        return;
      }

      if (request.method === 'GET' && requestUrl.pathname === '/_admin/status') {
        sendJson(response, 200, createStatusPayload(config, configStore));
        return;
      }

      if (request.method === 'GET' && requestUrl.pathname === '/_admin/config') {
        sendJson(response, 200, createConfigPayload(config));
        return;
      }

      if (request.method === 'PUT' && requestUrl.pathname === '/_admin/config') {
        const nextConfig = await readJsonBody(request);
        const savedConfig = configStore.setConfig(nextConfig);
        sendJson(response, 200, createConfigPayload(savedConfig));
        return;
      }

      if (request.method === 'GET' && requestUrl.pathname === '/v1/models') {
        if (activeProvider.useFakeModels && activeProvider.fakeModels.length > 0) {
          sendJson(response, 200, createModelList(activeProvider.fakeModels));
          return;
        }

        await forwardUpstreamRequest(request, response, {
          fetchImpl,
          provider: activeProvider,
          pathAndSearch: `${requestUrl.pathname}${requestUrl.search}`,
        });
        return;
      }

      if (request.method === 'GET' && requestUrl.pathname.startsWith('/v1/models/')) {
        if (activeProvider.useFakeModels && activeProvider.fakeModels.length > 0) {
          const modelId = decodeURIComponent(requestUrl.pathname.slice('/v1/models/'.length));
          const model = activeProvider.fakeModels.find((candidate) => candidate === modelId);

          if (!model) {
            sendError(response, 404, 'not_found_error', `Unknown model: ${modelId}`);
            return;
          }

          sendJson(response, 200, createModelRecord(model));
          return;
        }

        await forwardUpstreamRequest(request, response, {
          fetchImpl,
          provider: activeProvider,
          pathAndSearch: `${requestUrl.pathname}${requestUrl.search}`,
        });
        return;
      }

      if (
        request.method === 'POST' &&
        (requestUrl.pathname === '/v1/messages' || requestUrl.pathname.startsWith('/v1/messages/'))
      ) {
        await forwardUpstreamRequest(request, response, {
          fetchImpl,
          provider: activeProvider,
          pathAndSearch: `${requestUrl.pathname}${requestUrl.search}`,
        });
        return;
      }

      sendError(response, 404, 'not_found_error', `Unsupported route: ${request.method} ${requestUrl.pathname}`);
    } catch (error) {
      sendError(response, 502, 'upstream_error', error instanceof Error ? error.message : 'Unknown proxy error');
    }
  });
}
