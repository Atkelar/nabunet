using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Http;

namespace NabuNet
{
    public class ThemingRedirector
    {
        private readonly RequestDelegate _next;
        private readonly string _BaseFolder;
        private Dictionary<PathString, string> _mappings = new Dictionary<PathString, string>();

        public ThemingRedirector(RequestDelegate next)
        {
            _next = next;

            _BaseFolder = System.IO.Path.Combine(System.Environment.CurrentDirectory, "theming");

            AddMapping("/favicon.ico", "favicon.ico");
            AddMapping("/css/site.css", "site.css");
            AddMapping("/images/logo.png", "logo.png");
        }

        private void AddMapping(PathString target, string name)
        {
            string path = System.IO.Path.Combine(_BaseFolder, name);
            if (System.IO.File.Exists(path))
                _mappings.Add(target, path);
        }

        public async Task InvokeAsync(HttpContext context)
        {
            string? realFile;
            if (_mappings.TryGetValue(context.Request.Path, out realFile))
            {
                await context.Response.SendFileAsync(realFile);
            }
            else
                await _next(context);
        }
    }
}