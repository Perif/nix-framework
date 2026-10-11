{ homeDirectory }:
{
  OLLAYA_HOST = "127.0.0.1:11435";
  OLLAYA_DEVICE = "cpu";
  OLLAYA_MODELS = "${homeDirectory}/.ollaya/models";
  OLLAYA_MAX_LOADED_MODELS = "1";
  OLLAYA_MAX_QUEUE = "16";
  OLLAYA_KEEP_ALIVE = "5m";
}
