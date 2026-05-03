import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import os from 'node:os';
import { dirname } from 'node:path';

export const DEFAULT_MODELS = Object.freeze(['deepseek-v4-pro', 'deepseek-v4-flash']);
export const DEFAULT_UPSTREAM_BASE_URL = 'https://api.deepseek.com/anthropic';
export const DEFAULT_CONFIG_PATH = `${os.homedir()}/Library/Application Support/ClaudeAnthropicGateway/config.json`;

export function parseModelIds(value) {
  if (!value) {
    return [...DEFAULT_MODELS];
  }

  return value
    .split(',')
    .map((model) => model.trim())
    .filter(Boolean);
}

function normalizeBaseUrl(value, fallback) {
  const candidate = typeof value === 'string' && value.trim() ? value.trim() : fallback;
  return candidate.endsWith('/') ? candidate.slice(0, -1) : candidate;
}

function normalizeProviderId(value, index) {
  const candidate = typeof value === 'string' && value.trim() ? value.trim() : `provider-${index + 1}`;
  return candidate
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '') || `provider-${index + 1}`;
}

function createLegacyProvider(env) {
  return {
    id: 'deepseek',
    name: 'DeepSeek',
    baseUrl: normalizeBaseUrl(env.DEEPSEEK_ANTHROPIC_BASE_URL, DEFAULT_UPSTREAM_BASE_URL),
    apiKey: env.DEEPSEEK_API_KEY ?? env.ANTHROPIC_AUTH_TOKEN ?? '',
    useFakeModels: true,
    fakeModels: parseModelIds(env.DEEPSEEK_MODELS),
  };
}

function normalizeProvider(provider, index, env) {
  const legacyProvider = createLegacyProvider(env);
  const baseProvider = provider && typeof provider === 'object' ? provider : {};
  const hasExplicitFakeModels = Object.prototype.hasOwnProperty.call(baseProvider, 'fakeModels');
  const fakeModels = Array.isArray(baseProvider.fakeModels)
    ? baseProvider.fakeModels.map((model) => String(model).trim()).filter(Boolean)
    : hasExplicitFakeModels
      ? String(baseProvider.fakeModels ?? '')
          .split(',')
          .map((model) => model.trim())
          .filter(Boolean)
      : [...legacyProvider.fakeModels];

  return {
    id: normalizeProviderId(baseProvider.id, index),
    name:
      typeof baseProvider.name === 'string' && baseProvider.name.trim()
        ? baseProvider.name.trim()
        : legacyProvider.name,
    baseUrl: normalizeBaseUrl(baseProvider.baseUrl, legacyProvider.baseUrl),
    apiKey: typeof baseProvider.apiKey === 'string' ? baseProvider.apiKey : '',
    useFakeModels:
      typeof baseProvider.useFakeModels === 'boolean' ? baseProvider.useFakeModels : legacyProvider.useFakeModels,
    fakeModels,
  };
}

function createProviders(input, env) {
  if (Array.isArray(input?.providers) && input.providers.length > 0) {
    return input.providers.map((provider, index) => normalizeProvider(provider, index, env));
  }

  if (input?.provider && typeof input.provider === 'object') {
    return [normalizeProvider(input.provider, 0, env)];
  }

  if (input?.upstreamBaseUrl || input?.models || input?.apiKey) {
    return [
      normalizeProvider(
        {
          id: 'legacy',
          name: 'Legacy Provider',
          baseUrl: input.upstreamBaseUrl,
          apiKey: input.apiKey ?? '',
          useFakeModels: true,
          fakeModels: input.models ?? parseModelIds(env.DEEPSEEK_MODELS),
        },
        0,
        env,
      ),
    ];
  }

  return [createLegacyProvider(env)];
}

export function normalizeGatewayConfig(input = {}, env = process.env) {
  const providers = createProviders(input, env);
  const fallbackProviderId = providers[0]?.id ?? 'deepseek';
  const activeProviderId =
    typeof input.activeProviderId === 'string' && providers.some((provider) => provider.id === input.activeProviderId)
      ? input.activeProviderId
      : fallbackProviderId;
  const portCandidate = Number.parseInt(String(input.port ?? env.PORT ?? '8787'), 10);

  return {
    host: typeof input.host === 'string' && input.host.trim() ? input.host.trim() : env.HOST ?? '127.0.0.1',
    port: Number.isFinite(portCandidate) ? portCandidate : 8787,
    activeProviderId,
    providers,
  };
}

export function createDefaultGatewayConfig(env = process.env) {
  return normalizeGatewayConfig({}, env);
}

export function getActiveProvider(config) {
  return (
    config.providers.find((provider) => provider.id === config.activeProviderId) ??
    config.providers[0] ??
    createLegacyProvider(process.env)
  );
}

export function createInMemoryConfigStore(initialConfig = {}, env = process.env) {
  let config = normalizeGatewayConfig(initialConfig, env);

  return {
    getConfig() {
      return config;
    },
    setConfig(nextConfig) {
      config = normalizeGatewayConfig(nextConfig, env);
      return config;
    },
  };
}

export function createFileBackedConfigStore(options = {}) {
  const configPath = options.configPath ?? DEFAULT_CONFIG_PATH;
  const env = options.env ?? process.env;
  let cachedConfig = createDefaultGatewayConfig(env);

  function ensureConfigFile() {
    mkdirSync(dirname(configPath), { recursive: true });

    try {
      readFileSync(configPath, 'utf8');
    } catch {
      writeFileSync(configPath, `${JSON.stringify(cachedConfig, null, 2)}\n`, 'utf8');
    }
  }

  function loadConfigFromDisk() {
    ensureConfigFile();

    try {
      const raw = readFileSync(configPath, 'utf8');
      const parsed = JSON.parse(raw);
      cachedConfig = normalizeGatewayConfig(parsed, env);
      return cachedConfig;
    } catch {
      return cachedConfig;
    }
  }

  function saveConfig(nextConfig) {
    cachedConfig = normalizeGatewayConfig(nextConfig, env);
    mkdirSync(dirname(configPath), { recursive: true });
    writeFileSync(configPath, `${JSON.stringify(cachedConfig, null, 2)}\n`, 'utf8');
    return cachedConfig;
  }

  cachedConfig = loadConfigFromDisk();

  return {
    configPath,
    getConfig: loadConfigFromDisk,
    setConfig: saveConfig,
  };
}
