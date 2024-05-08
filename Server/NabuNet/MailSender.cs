using System;
using System.IO;
using System.Linq.Expressions;
using System.Threading.Tasks;
using MailKit.Net.Smtp;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using SixLabors.ImageSharp.Formats.Tiff.Constants;

namespace NabuNet
{
    public class MailSender
        : IMailSender
    {
        private readonly IServerConfigFactory _Config;
        private readonly ILogger<MailSender> _Logger;
        private readonly MailConfig _Mail;
        private readonly ITemplateManager _Templates;

        public MailSender(ILogger<MailSender> logger, IServerConfigFactory config, IOptions<MailConfig> mail, ITemplateManager tpl)
        {
            _Config = config;
            _Logger = logger;
            _Mail = mail.Value;
            _Templates = tpl;
        }

        public async Task<bool> TrySendMail(MailingParameters input)
        {
            try
            {
                _Logger.LogInformation("Seinding {key} template...", input.MailTemplateKey);

                TemplateContent? content = await _Templates.LoadTemplateAsync(input.MailTemplateKey);

                if (content == null)
                    return false;

                _Logger.LogTrace("Preparing Mail message by template {tpl}", input.MailTemplateKey);

                var cfg = await _Config.GetOrLoad();

                input.Values.Add("url", cfg.BaseUrl);
                input.Values.Add("servername", cfg.ServerName);
                input.Values.Add("servertagline", cfg.ServerTagLine);
                input.Values.Add("now", cfg.GetFormattedServerTime(true));

                if (_Logger.IsEnabled(LogLevel.Trace))
                {
                    foreach(var k in input.Values)
                    {
                        _Logger.LogTrace("  {key}: {value}", k.Key, k.Value);
                    }
                }

                var subject = HandlebarsDotNet.Handlebars.Compile(content.Subject);
                var body = HandlebarsDotNet.Handlebars.Compile(content.Body);

                string txtSubject = subject(input.Values);
                string txtBody = body(input.Values);

                _Logger.LogTrace("Subject: {subject}", txtSubject);
                _Logger.LogTrace("Body:\n{body}", txtBody);

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

                var from = new MimeKit.MailboxAddress(_Mail.SenderName, _Mail.SenderAddress);
                msg.From.Add(from);
                msg.Sender = from;

                if (_Logger.IsEnabled(LogLevel.Trace))
                {
                    _Logger.LogTrace("From: {from}", from);
                    foreach(var x in msg.To)
                        _Logger.LogTrace("  To: {to}", x);
                    foreach(var x in msg.Cc)
                        _Logger.LogTrace("  CC: {cc}", x);
                    foreach(var x in msg.Bcc)
                        _Logger.LogTrace("  BCC: {bcc}", x);
                }

                _Logger.LogInformation("Mail server {server}:{port}...", _Mail.Server, _Mail.Port);

                SmtpClient cli = new SmtpClient();
                await cli.ConnectAsync(_Mail.Server, _Mail.Port);

                if (!string.IsNullOrWhiteSpace(_Mail.User) || !string.IsNullOrWhiteSpace(_Mail.Password))
                {
                    _Logger.LogInformation("...auth: {user}", _Mail.User);
                    await cli.AuthenticateAsync(_Mail.User, _Mail.Password);
                }

                var result = await cli.SendAsync(msg);
                _Logger.LogInformation("...result: {result}", result);
                await cli.DisconnectAsync(true);
                return true;
            }
            catch (Exception ex)
            {
                _Logger.LogError(ex, "Mail sending failed!");
                return false;
            }
        }
    }
}