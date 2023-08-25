using System.Diagnostics;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging;
using NabuNet.Models;

namespace NabuNet.Controllers;

[Authorize(SecurityPolicy.SiteAdmin)]
public class AdminController : NabuControllerBase
{
    private readonly ILogger _logger;
    private readonly IServerConfigFactory _Settings;

    public AdminController(ILogger<AdminController> logger, IServerConfigFactory settings)
    {
        _logger = logger;
        _Settings = settings;
    }

    [HttpGet]
    public async Task<IActionResult> Index()
    {
        return View();
    }

    [HttpGet]
    public async Task<IActionResult> Status()
    {
        var cfg = await _Settings.GetOrLoad();

        if (cfg.ServerMessage != null)
        {
            return View(new ArticleInputDto() { Title = cfg.ServerMessage.Title, Article = cfg.ServerMessage.Article, ReferenceDate = cfg.ServerMessage.ReferenceDate });
        }

        return View();
    }

    [HttpGet]
    public async Task<IActionResult> Imprint()
    {
        var cfg = await _Settings.GetOrLoad();

        return View(new ImprintDto() { Article = cfg.Imprint?.Article ?? string.Empty, Title = cfg.Imprint?.Title ?? string.Empty });
    }

    [HttpPost]
    public async Task<IActionResult> RemoveImprint()
    {
        if (!ModelState.IsValid)
            return RedirectToAction(nameof(Imprint));

        var cfg = await _Settings.GetOrLoad();
        await cfg.ClearImprint();

        return RedirectToAction(nameof(Imprint));
    }

    [HttpPost]
    public async Task<IActionResult> Imprint(ImprintDto input)
    {
        if (!ModelState.IsValid)
            return View();


        var cfg = await _Settings.GetOrLoad();
        await cfg.SetImprint(input.Title, input.Article);

        return RedirectToAction(nameof(Imprint));
    }

    [HttpPost]
    public async Task<IActionResult> Status(ArticleInputDto input)
    {
        if (!ModelState.IsValid)
            return View();

        var cfg = await _Settings.GetOrLoad();
        await cfg.SetServerMessage(input.Title, input.Article ?? string.Empty, input.ReferenceDate);

        return RedirectToAction("Index", "Home");
    }
    [HttpPost]
    public async Task<IActionResult> RemoveStatus()
    {
        var cfg = await _Settings.GetOrLoad();
        await cfg.ClearServerMessage();
        return RedirectToAction("Index", "Home");
    }
}
