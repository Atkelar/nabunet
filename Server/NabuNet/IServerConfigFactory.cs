using System.Threading.Tasks;

namespace NabuNet
{
    public interface IServerConfigFactory
    {
        Task<ServerConfig> GetOrLoad();
    }
}