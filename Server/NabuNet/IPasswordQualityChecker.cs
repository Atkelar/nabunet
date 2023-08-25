using System.Threading.Tasks;

namespace NabuNet
{
    public interface IPasswordQualityChecker
    {
        Task<string?> GetErrorForPasswordQuality(string propesedPassword);
    }
}