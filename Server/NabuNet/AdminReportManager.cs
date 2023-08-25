using System.Threading.Tasks;

namespace NabuNet
{
    public class AdminReportManager
        : IAdminReportManager
    {
        private IDatabase _Database;

        public AdminReportManager(IDatabase database)
        {
            _Database = database;
        }

        private const string AdminReportName = "adminreport";
        public async Task CreateAdminReportAsync(string? name, string? userName, string topic, string? message)
        {
            ReportedIssue msg = new ReportedIssue();
            msg.UserName = name;
            msg.RelatedUser = userName;
            msg.TopicCode = topic;
            msg.Message = message;
            await _Database.SetDocumentAsync(AdminReportName, msg);
        }
    }
}