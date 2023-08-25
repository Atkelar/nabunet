using System.IO;
using System.Threading.Tasks;
using MailKit.Net.Smtp;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;

namespace NabuNet
{
    public class MailSender
        : IMailSender
    {
        private readonly IServerConfigFactory _Config;
        private readonly ILogger<MailSender> _Logger;
        private readonly StorageConfig _Storage;
        private readonly MailConfig _Mail;

        public MailSender(ILogger<MailSender> logger, IServerConfigFactory config, IOptions<StorageConfig> storage, IOptions<MailConfig> mail)
        {
            _Config = config;
            _Logger = logger;
            _Storage = storage.Value;
            _Mail = mail.Value;
        }

        public async Task<bool> TrySendMail(MailingParameters input)
        {
            string templatePath = System.IO.Path.Combine(_Storage.BaseFolder, _Storage.MailTemplateFolder, $"{input.MailTemplateKey.ToLowerInvariant()}.tpl");
            if (!File.Exists(templatePath))
            {
                string baseFolder = System.IO.Path.Combine(_Storage.BaseFolder, _Storage.MailTemplateFolder);
                if (!Directory.Exists(baseFolder))
                    Directory.CreateDirectory(baseFolder);
                string stubPath = System.IO.Path.Combine(System.Environment.CurrentDirectory, "stubtemplates", $"{input.MailTemplateKey.ToLowerInvariant()}.tpl");
                if (File.Exists(stubPath))
                    File.Copy(stubPath, templatePath);
                else
                    return false;
            }

            var cfg = await _Config.GetOrLoad();

            input.Values.Add("url", cfg.BaseUrl);
            input.Values.Add("servername", cfg.ServerName);
            input.Values.Add("servertagline", cfg.ServerTagLine);
            input.Values.Add("now", cfg.GetFormattedServerTime(true));

            using (var r = File.OpenText(templatePath))
            {
                var subject = HandlebarsDotNet.Handlebars.Compile(await r.ReadLineAsync());
                var body = HandlebarsDotNet.Handlebars.Compile(await r.ReadToEndAsync());

                string txtSubject = subject(input.Values);
                string txtBody = body(input.Values);

                MimeKit.MimeMessage msg = new MimeKit.MimeMessage();
                if (input.Recipients != null)
                    foreach (var a in input.Recipients)
                        msg.To.Add(new MimeKit.MailboxAddress(a, a));
                if (input.CCRecipients != null)
                    foreach (var a in input.CCRecipients)
                        msg.Cc.Add(new MimeKit.MailboxAddress(a, a));
                if (input.BCCRecipients != null)
                    foreach (var a in input.BCCRecipients)
                        msg.Bcc.Add(new MimeKit.MailboxAddress(a, a));

                msg.Subject = txtSubject;
                msg.Body = new MimeKit.TextPart("html") { Text = txtBody };

                msg.From.Add(new MimeKit.MailboxAddress(_Mail.SenderName, _Mail.SenderAddress));
                msg.Sender = new MimeKit.MailboxAddress(_Mail.SenderName, _Mail.SenderAddress);

                SmtpClient cli = new SmtpClient();
                await cli.ConnectAsync(_Mail.Server, _Mail.Port);

                if (!string.IsNullOrWhiteSpace(_Mail.User) || !string.IsNullOrWhiteSpace(_Mail.Password))
                {
                    await cli.AuthenticateAsync(_Mail.User, _Mail.Password);
                }

                var result = await cli.SendAsync(msg);
                _Logger.LogTrace(result);
                await cli.DisconnectAsync(true);
            }
            return true;
        }
    }
}