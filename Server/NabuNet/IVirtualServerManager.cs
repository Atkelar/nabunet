using System.Collections.Generic;
using System.Threading.Tasks;

namespace NabuNet
{
    public interface IVirtualServerManager
    {
        Task<IEnumerable<VirtualServerInfo>> GetList();

        Task<VirtualServerDetails?> GetDetails(int code, bool onylEnabled);
        Task UpdateOwner(int id, string newOwner);
        Task UpdateName(int id, string newName);
        Task SetEnabled(int id, bool value);
        Task SetKernelAsset(int id, int value);
        Task SetLoaderAsset(int id, int value);
    }
}