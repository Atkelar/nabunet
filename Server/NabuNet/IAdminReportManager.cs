using System.Threading.Tasks;

namespace NabuNet
{
    public interface IAdminReportManager
    {
        Task CreateAdminReportAsync(string? name, string? userName, string topic, string? message);
    }

}