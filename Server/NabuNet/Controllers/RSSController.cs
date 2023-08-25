using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Threading.Tasks;
using System.Xml;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging;
using NabuNet.Models;

namespace NabuNet.Controllers;

public class RSSController : Controller
{
    private readonly ILogger _logger;
    private readonly IServerConfigFactory _Settings;

    public RSSController(ILogger<RSSController> logger, IServerConfigFactory settings)
    {
        _logger = logger;
        _Settings = settings;
    }

    private class RssFeed
    {
        public RssFeed(string title, string link, string? description = null)
        {
            this.Description = description;
            this.Link = link;
            this.Title = title;
        }

        public void AppendItem(string title, string link, string? description)
        {
            _Items.Add(new RssItem(title, link, description));
        }

        private class RssItem
        {
            public RssItem(string title, string link, string? description = null)
            {
                this.Description = description;
                this.Link = link;
                this.Title = title;
            }
            public string? Description { get; }
            public string Link { get; }
            public string Title { get; }
        }

        private List<RssItem> _Items = new List<RssItem>();

        public string? Description { get; }
        public string Link { get; }
        public string Title { get; }

        internal Stream ToStream()
        {
            var doc = new XmlDocument();
            doc.AppendChild(doc.CreateXmlDeclaration("1.0", null, null));
            doc.AppendChild(doc.CreateElement("rss"));
            doc.DocumentElement?.SetAttribute("version", "2.0");
            var channel = doc.CreateElement("channel");
            doc.DocumentElement?.AppendChild(channel);
            var e = doc.CreateElement("title");
            e.InnerText = Title;
            channel.AppendChild(e);
            e = doc.CreateElement("link");
            e.InnerText = Link;
            channel.AppendChild(e);
            e = doc.CreateElement("description");
            e.InnerText = Description;
            channel.AppendChild(e);

            foreach (var item in _Items)
            {
                e = doc.CreateElement("item");
                channel.AppendChild(e);
                var e1 = doc.CreateElement("title");
                e1.InnerText = item.Title;
                e.AppendChild(e1);
                e1 = doc.CreateElement("link");
                e1.InnerText = item.Link;
                e.AppendChild(e1);
                if (item.Description != null)
                {
                    e1 = doc.CreateElement("description");
                    e1.InnerText = item.Description;
                }
                e.AppendChild(e1);
            }

            MemoryStream stream = new MemoryStream();
            doc.Save(stream);
            stream.Seek(0, SeekOrigin.Begin);
            return stream;
        }
    }

    public async Task<ActionResult> ServerStatus()
    {
        var cfg = await _Settings.GetOrLoad();
        var rss = new RssFeed($"{cfg.ServerName} Status", $"{cfg.BaseUrl}", $"Server status updates and notifications for {cfg.ServerName} - {cfg.ServerTagLine}");

        if (cfg.ServerMessage != null)
        {
            var msg = cfg.ServerMessage;
            rss.AppendItem(msg.Title, $"{cfg.BaseUrl}Home/Status", (string.IsNullOrWhiteSpace(msg.Article) ? "No details associated (yet?)" : "See the server URI for more information!") + (msg.ReferenceDate.HasValue ? $" - this information partains to {msg.ReferenceDate:yyyy-MM-dd HH:mm:ss}" : ""));
        }

        var stream = rss.ToStream();

        return File(stream, "text/xml");
    }
}
