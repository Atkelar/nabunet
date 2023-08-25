using System.Threading.Tasks;

namespace NabuNet
{
    public class ServerConfigFactory
        : IServerConfigFactory
    {
        private readonly ServerConfig _Config;

        public ServerConfigFactory(ServerConfig cfg)
        {
            _Config = cfg;
        }
        public async Task<ServerConfig> GetOrLoad()
        {
            if (!_Config.IsLoaded)
                await _Config.ReloadSettings();
            return _Config;
        }
    }
}