using System;
using System.ComponentModel.DataAnnotations;
using System.Diagnostics;
using System.Linq;
using System.Threading.Tasks;
using Captcha.Core;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using NabuNet.Models;

namespace NabuNet.Controllers
{

    [Authorize(Policy = SecurityPolicy.User)]
    public class ContactController : NabuControllerBase
    {
        private readonly ILogger _logger;
        private readonly IServerConfigFactory _Settings;
        private readonly IUserManager _UserManager;
        private readonly IAdminReportManager _Reports;

        public ContactController(ILogger<ContactController> logger, IServerConfigFactory settings, IUserManager userManager, IAdminReportManager reports)
        {
            _logger = logger;
            _Settings = settings;
            _UserManager = userManager;
            _Reports = reports;
        }

        private ReportInputDto PrepareReport(string topic, string? userhint)
        {
            string topicText = TopicFromCode(topic);
            if (!ModelState.IsValid || string.IsNullOrWhiteSpace(topicText))
                return null;
            var data = new ReportInputDto();
            if (userhint != null && this.User.Identity.IsAuthenticated)
            {
                data.WarnUserMismatch = true;
            }
            data.TopicCode = topic;
            data.UserName = userhint ?? this.User?.Identity?.Name;
            data.Topic = topicText;
            return data;
        }

        [AllowAnonymous]
        public async Task<IActionResult> Report([Required][FromQuery] string topic, [FromQuery] string? userhint = null)
        {
            ReportInputDto? data = PrepareReport(topic, userhint);
            if (data == null)
                return RedirectToAction("Index", "Home");

            data.Message = string.Empty;
            return View(data);
        }

        [ValidateCaptcha(ErrorMessage = "Please enter the security code as a number.",
                    CaptchaGeneratorLanguage = Language.English,
                    CaptchaGeneratorDisplayMode = DisplayMode.NumberToWord)]
        [AllowAnonymous]
        [HttpPost]
        public async Task<IActionResult> Report([Required][FromQuery] string topic, [FromQuery] string? userhint = null, [FromForm] string? message = null)
        {
            ReportInputDto? data = PrepareReport(topic, userhint);
            if (data == null)
                return RedirectToAction("Index", "Home");

            data.Message = message;
            if (!ModelState.IsValid)
                return View(data);

            await _Reports.CreateAdminReportAsync(User?.Identity?.Name, data.UserName, topic, message);

            return View("reportcreated");
        }

        private string? TopicFromCode(string topic)
        {
            switch (topic)
            {
                case "emu": return "Possible E-Mail Update Abuse";
                case "2fa": return "Possible 2FA Reset Abuse";
                default: return null;
            }
        }
    }

}