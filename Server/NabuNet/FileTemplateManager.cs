using System;
using System.IO;
using System.Threading.Tasks;
using Microsoft.Extensions.Options;

namespace NabuNet
{
    public class FileTemplateManager
        : ITemplateManager
    {
        private readonly StorageConfig _Storage;

        public FileTemplateManager(IOptions<StorageConfig> storage)
        {
            _Storage = storage.Value;
        }
        public async Task<TemplateContent?> LoadTemplateAsync(string mailTemplateKey)
        {
            string templatePath = System.IO.Path.Combine(_Storage.BaseFolder, _Storage.MailTemplateFolder, $"{mailTemplateKey.ToLowerInvariant()}.tpl");
            if (!File.Exists(templatePath))
            {
                string baseFolder = System.IO.Path.Combine(_Storage.BaseFolder, _Storage.MailTemplateFolder);
                if (!Directory.Exists(baseFolder))
                    Directory.CreateDirectory(baseFolder);
                string stubPath = System.IO.Path.Combine(System.Environment.CurrentDirectory, "stubtemplates", $"{mailTemplateKey.ToLowerInvariant()}.tpl");
                if (File.Exists(stubPath))
                    File.Copy(stubPath, templatePath);
                else
                    return null;
            }
            var result = new TemplateContent();
            using (var r = File.OpenText(templatePath))
            {
                result.Subject = await r.ReadLineAsync() ?? "";
                result.Body = await r.ReadToEndAsync();
            }
            return result;
        }

        public async Task UpdateTemplateAsync(string mailTemplateKey, string subject, string body)
        {
            var tplNow = await LoadTemplateAsync(mailTemplateKey);
            if (tplNow == null)
                throw new InvalidOperationException($"Template {mailTemplateKey} not found!");
            string templatePath = System.IO.Path.Combine(_Storage.BaseFolder, _Storage.MailTemplateFolder, $"{mailTemplateKey.ToLowerInvariant()}.tpl");
            using (var r = File.CreateText(templatePath))
            {
                await r.WriteLineAsync(subject);
                await r.WriteAsync(body);
            }
        }
    }
}