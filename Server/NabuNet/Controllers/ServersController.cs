using System;
using System.Diagnostics;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Filters;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using NabuNet.Models;

namespace NabuNet.Controllers
{

    public class ServersController : NabuControllerBase
    {
        private readonly ILogger _logger;
        private readonly IServerConfigFactory _Settings;
        private readonly IUserManager _UserManager;
        private readonly IVirtualServerManager _Servers;

        public ServersController(ILogger<ServersController> logger, IServerConfigFactory settings, IUserManager userManager, IVirtualServerManager servers)
        {
            _logger = logger;
            _Settings = settings;
            _UserManager = userManager;
            _Servers = servers;
        }

        [HttpGet]
        public async Task<IActionResult> Index()
        {
            var cfg = await _Settings.GetOrLoad();

            var list = new ServerListModel();
            ViewBag.HasVirtualServers = list.HasVirtualServers = cfg.EnableVirtualServers;

            var servers = await _Servers.GetList();
            list.RootServer = servers.First(x => x.Code == 0);

            if (list.HasVirtualServers)
            {
                list.Virtuals = servers.Where(x => x.Code != 0);
            }
            else
            {
                list.Virtuals = Array.Empty<VirtualServerInfo>();
            }

            return View(list);
        }


    }
}