using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Security.Claims;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication.Cookies;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.DataProtection;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using NabuNet.Models;

namespace NabuNet.Controllers;

public class LoginController : NabuControllerBase
{
    private readonly ILogger _logger;
    private readonly IServerConfigFactory _Settings;
    private readonly IUserManager _UserManager;
    private readonly IDataProtector _Protection;
    private readonly LoginSettings _LoginOptions;

    public LoginController(
        ILogger<LoginController> logger,
        IServerConfigFactory settings,
        IUserManager userManager,
        IDataProtectionProvider protectionProvider,
        IOptions<LoginSettings> loginOptions)
    {
        _logger = logger;
        _Settings = settings;
        _UserManager = userManager;
        _Protection = protectionProvider.CreateProtector("login");
        _LoginOptions = loginOptions.Value;
    }

    [AllowAnonymous]
    [HttpGet]
    public IActionResult Index([FromQuery] string? returnUrl = null)
    {
        // if ((User.Identity?.IsAuthenticated).GetValueOrDefault())   // already logged in, redirect to homepage...
        //     return RedirectToAction("Index", "Home");
        return View(new LoginModel() { UserName = User.Identity.IsAuthenticated ? User.Identity.Name : string.Empty });
    }

    [AllowAnonymous]
    [HttpPost]
    public async Task<IActionResult> Login(LoginModel loginInfo, [FromQuery] string? returnUrl = null)
    {
        ViewBag.ReturnUrl = returnUrl;
        if ((User.Identity?.IsAuthenticated).GetValueOrDefault())   // already logged in, redirect to homepage...
            return RedirectToAction("Index", "Home");
        if (!ModelState.IsValid)
            return View("Index");
        // validate password and login or redirect to 2FA page...
        switch (await _UserManager.ValidateUserPassword(loginInfo.UserName, loginInfo.Password))
        {
            case UserLoginStep1Result.Success:
                // logged in and validated, no 2FA...
                var user = await _UserManager.CreatePrincipal(loginInfo.UserName, false);
                if (user != null)
                    await HttpContext.SignInAsync(CookieAuthenticationDefaults.AuthenticationScheme, user);
                return string.IsNullOrWhiteSpace(returnUrl) ? RedirectToAction("Index", "Home") : LocalRedirect(returnUrl);
            case UserLoginStep1Result.GetFactorTwo:
                return View("promptfactortwo", new LoginModel2FA() { UserName = loginInfo.UserName, LoginToken = await _UserManager.GetPageForwardToken(loginInfo.UserName) });
            case UserLoginStep1Result.SetupFactorTwo:
                return View("setupfactortwo", new Setup2FAModel() { UserName = loginInfo.UserName, Parameters = await _UserManager.GetNew2FAChallenge(loginInfo.UserName) });
            case UserLoginStep1Result.ForceNewPassword:
                return View("forcepasswordchange", new ForcePasswordChangeModel() { UserName = loginInfo.UserName, Token = await _UserManager.GetPageForwardToken(loginInfo.UserName) });
            default:
                ModelState.AddModelError(string.Empty, "User/password combination is not valid.");
                await Task.Delay(Random.Shared.Next(3) + 1);    // slow down a bit...
                return View("Index");
        }
    }

    [AllowAnonymous]
    [HttpPost]
    public async Task<IActionResult> StepTwo(LoginModel2FA input, [FromQuery] string? returnUrl = null)
    {
        ViewBag.ReturnUrl = returnUrl;
        if (ModelState.IsValid)
        {
            if (!await _UserManager.ValidatePageForwardToken(input.UserName, input.LoginToken))
            {
                ModelState.AddModelError(string.Empty, "The login process expired, please retry!");
                return View("index");
            }
            if (await _UserManager.ValidateUser2FA(input.UserName, input.ResponseCode))
            {
                var user = await _UserManager.CreatePrincipal(input.UserName, true);
                if (user != null)
                    await HttpContext.SignInAsync(CookieAuthenticationDefaults.AuthenticationScheme, user);
                return string.IsNullOrWhiteSpace(returnUrl) ? RedirectToAction("Index", "Home") : LocalRedirect(returnUrl);
            }
        }

        await Task.Delay((Random.Shared.Next(4) + 1) * 500);    // slow down...
        ModelState.Remove(nameof(input.ResponseCode));
        ModelState.AddModelError(string.Empty, "The code didn't validate, please try again...");
        return View("promptfactortwo", new LoginModel2FA() { UserName = input.UserName, LoginToken = await _UserManager.GetPageForwardToken(input.UserName) });
    }

    [AllowAnonymous]
    [HttpPost]
    public async Task<IActionResult> Login2FA(LoginModel2FA loginInfo, [FromQuery] string? returnUrl = null)
    {
        ViewBag.ReturnUrl = returnUrl;
        if ((User.Identity?.IsAuthenticated).GetValueOrDefault())   // already logged in, redirect to homepage...
            return RedirectToAction("Index", "Home");
        if (!ModelState.IsValid)
            return View("login2fa");
        var cfg = await _Settings.GetOrLoad();

        // validate password and login or redirect to 2FA page...
        if ((await _UserManager.ValidatePageForwardToken(loginInfo.UserName, loginInfo.LoginToken)) && await (_UserManager.ValidateUser2FA(loginInfo.UserName, loginInfo.ResponseCode)))
        {
            // logged in and validated, no 2FA...
            var user = await _UserManager.CreatePrincipal(loginInfo.UserName, true);
            if (user != null)
            {
                await HttpContext.SignInAsync(CookieAuthenticationDefaults.AuthenticationScheme, user);
                return string.IsNullOrWhiteSpace(returnUrl) ? RedirectToAction("Index", "Home") : LocalRedirect(returnUrl);
            }
        }
        ModelState.AddModelError(string.Empty, "User/password combination is not valid.");
        await Task.Delay(Random.Shared.Next(3) + 1);    // slow down a bit...
        return View("login2fa");
    }

    [Authorize("user")]
    [HttpPost]
    public async Task<IActionResult> Logout()
    {
        await HttpContext.SignOutAsync();
        return RedirectToAction("Index", "Home");
    }

}