import {
  createDefaultGatewayConfig,
  createFileBackedConfigStore,
  DEFAULT_CONFIG_PATH,
  getActiveProvider,
} from './config.js';
import { createAnthropicProxyServer } from './proxy.js';

const configStore = createFileBackedConfigStore({
  configPath: process.env.GATEWAY_CONFIG_PATH ?? DEFAULT_CONFIG_PATH,
});
const config = configStore.getConfig();
const activeProvider = getActiveProvider(config);
const server = createAnthropicProxyServer({ configStore });

server.listen(config.port, config.host, () => {
  const currentConfig = configStore.getConfig();
  const currentProvider = getActiveProvider(currentConfig);

  console.log(`Claude Anthropic gateway listening on http://${currentConfig.host}:${currentConfig.port}`);
  console.log(`Config: ${configStore.configPath ?? DEFAULT_CONFIG_PATH}`);
  console.log(`Provider: ${currentProvider.name} (${currentProvider.baseUrl})`);
  console.log(
    `Fake models: ${currentProvider.useFakeModels ? currentProvider.fakeModels.join(', ') : 'disabled'}`,
  );
});
