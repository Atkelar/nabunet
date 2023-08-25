using System.Threading.Tasks;
using NabuNet.ProgramModel;

namespace NabuNet
{
    public interface IAssetManager
    {
        Task<ProgramModel.AssetDefinition> CreateAssetFromBlob(System.IO.Stream data);

        Task<ProgramModel.AssetDefinition?> GetInfo(int assetId);

        Task<bool> Exists(int assetId);

        Task<(byte[]? Result, int filesize)> GetBlockFromFile(int assetId, string filename, int offset, int blockSize);
    }
}