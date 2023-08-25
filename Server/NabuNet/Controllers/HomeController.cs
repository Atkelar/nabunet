using System;
using System.Collections;
using System.Collections.Generic;
using System.Diagnostics;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging;
using NabuNet.Models;
using SixLabors.ImageSharp.ColorSpaces;

namespace NabuNet.Controllers;

public class HomeController : NabuControllerBase
{
    private readonly ILogger _logger;
    private readonly IServerConfigFactory _Settings;

    public HomeController(ILogger<HomeController> logger, IServerConfigFactory settings)
    {
        _logger = logger;
        _Settings = settings;
    }

    public async Task<IActionResult> About([FromServices] IEnumerable<ILibraryCredits> creditsFrom)
    {
        var data = new AboutPageModel() { Version = this.GetType().Assembly.GetName()?.Version?.ToString() ?? "?" };
        var list = new List<Tuple<string, IEnumerable<LibraryInfo>>>();
        foreach (var cf in creditsFrom)
        {
            var tp = new List<LibraryInfo>();
            var credits = await cf.GetLirbaryInfoAsync();
            tp.AddRange(credits.OrderBy(x => x.Name));
            if (tp.Count > 0)
            {
                list.Add(new Tuple<string, IEnumerable<LibraryInfo>>(cf.Category, tp));
            }
        }
        data.Libraries = list.OrderBy(x => x.Item1).ToList();

        var cfg = await _Settings.GetOrLoad();

        data.Imprint = cfg.Imprint;

        return View(data);
    }

    public IActionResult Index()
    {
        return View();
    }

    public async Task<IActionResult> Status()
    {
        var msg = (await _Settings.GetOrLoad()).ServerMessage;
        return View(msg);
    }

    public async Task<IActionResult> Privacy()
    {
        string policy = await (await _Settings.GetOrLoad()).GetPrivacyPolicy();
        return View((object)policy);    // string as model...
    }

    public async Task<IActionResult> Terms()
    {
        string terms = await (await _Settings.GetOrLoad()).GetTermsOfService();
        return View((object)terms);    // string as model...
    }

    [ResponseCache(Duration = 0, Location = ResponseCacheLocation.None, NoStore = true)]
    public IActionResult Error()
    {
        return View(new ErrorViewModel { RequestId = Activity.Current?.Id ?? HttpContext.TraceIdentifier });
    }
}
