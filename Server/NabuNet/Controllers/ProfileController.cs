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

    // profile controller replies with security relevant info; 
    // make absolutely sure that nobody keeps track of that!
    // Two reasons: update conflicts in profile data and 
    // the "2FA init" QR Code and Link that might be sent!
    [ResponseCache(NoStore = true, Location = ResponseCacheLocation.None)]
    [Authorize(Policy = SecurityPolicy.User)]
    public class ProfileController : NabuControllerBase
    {
        private readonly ILogger _logger;
        private readonly IServerConfigFactory _Settings;
        private readonly IUserManager _UserManager;

        public ProfileController(ILogger<ProfileController> logger, IServerConfigFactory settings, IUserManager userManager)
        {
            _logger = logger;
            _Settings = settings;
            _UserManager = userManager;
        }

        // ID = profile "page" via routing...
        [HttpGet]
        public async Task<IActionResult> Index(string? id)
        {
            id = (id ?? "").ToLowerInvariant();
            var userProfile = await _UserManager.GetProfileByName(User.Identity.Name);
            if (userProfile == null)
                return NotFound();  // somewhat critical...

            switch (id)
            {
                case "":
                    return View("index-basic", new BasicProfileInfo(userProfile));
                case "security":
                    return View("index-security", new ProfileSecurityInfo() { IsMFAEnabled = await _UserManager.IsMFAEnabled(userProfile.Name) });
                case "tokens":
                    return View("index-tokens", new TokenListDto(userProfile, await _UserManager.GetTokensForUser(userProfile.Name)));
            }
            return NotFound();
        }

        [HttpPost()]
        [ActionName("deletetoken")]
        public async Task<IActionResult> DeleteToken([FromForm][Required] string id)
        {
            id = (id ?? "").ToLowerInvariant();
            var userProfile = await _UserManager.GetProfileByName(User.Identity.Name);
            if (userProfile == null)
                return NotFound();  // somewhat critical...
            Guid gid;
            if (!Guid.TryParse(id, out gid))
                return NotFound();

            await _UserManager.DeleteUserToken(userProfile.Name, gid);
            return RedirectToAction(nameof(Index), new { Id = "tokens" });
        }

        [HttpGet()]
        [ActionName("deletetoken")]
        public async Task<IActionResult> DeleteTokenPrompt([FromRoute] string id)
        {
            id = (id ?? "").ToLowerInvariant();
            var userProfile = await _UserManager.GetProfileByName(User.Identity.Name);
            if (userProfile == null)
                return NotFound();  // somewhat critical...
            Guid gid;
            if (!Guid.TryParse(id, out gid))
                return NotFound();

            var token = (await _UserManager.GetTokensForUser(userProfile.Name)).Where(x => x.Id == gid).FirstOrDefault();
            if (token == null)
                return RedirectToAction(nameof(Index), new { Id = "tokens" });

            return View(new TokenInfoDto() { Id = token.Id.ToString("n"), ExpiresAt = token.ExpiresAt, IssuedAt = token.IssuedAt, Name = token.Name, IsContentManager = token.IsContentManager, IsModerator = token.IsModerator, IsSiteAdmin = token.IsSiteAdmin, IsUserAdmin = token.IsUserAdmin });
        }

        [HttpPost]
        public async Task<IActionResult> UpdateBasic(BasicProfileInfo input)
        {
            if (ModelState.IsValid)
            {
                var userProfile = await _UserManager.GetProfileByName(User.Identity.Name);
                if (userProfile == null)
                    return NotFound();  // somewhat critical...
                if (userProfile.ContactEMail != input.EMailAddress)
                {
                    // initiate an e-mail update process...
                    await _UserManager.StartEMailUpdate(User.Identity.Name, input.EMailAddress);
                }
                await _UserManager.UpdateProfileByName(User.Identity.Name, input.DisplayName, input.HighScoreName, input.AllowAPIAccess, input.AllowDeviceAccess);
                return RedirectToAction("index"); // , new { id = "basic" }
            }
            return View("index-basic");
        }

        [AllowAnonymous]
        [HttpGet]
        public async Task<IActionResult> Signup([FromServices] IOptions<LoginSettings> loginOptions, [FromQuery] string? returnUrl = null)
        {
            ViewBag.ReturnUrl = returnUrl;
            return View(new SignUpModel() { Requries2FA = loginOptions.Value.Require2FASignup });
        }

        [AllowAnonymous]
        [HttpGet]
        public async Task<IActionResult> MailValidate([FromQuery] string code, [FromQuery] string token, [FromServices] IOptions<LoginSettings> loginOptions, [FromQuery] string? returnUrl = null)
        {
            ViewBag.ReturnUrl = returnUrl;
            if (string.IsNullOrWhiteSpace(token) || string.IsNullOrWhiteSpace(code))
                return NotFound();

            string? username = await _UserManager.ExtractUserFromTokenForMailValidationAndCheck(token, code);
            if (username == null)
                return View("mailtokenexpired");

            if (User.Identity.IsAuthenticated && !User.Identity.Name.Equals(username, System.StringComparison.InvariantCultureIgnoreCase))
            {
                return View("mailvalidatemismatch");
            }

            var profile = await _UserManager.GetProfileByName(username);

            return View(new ConfirmMailForAccountModel() { EMail = profile.ContactEMail, UserName = username, ValidationCode = code, Token = token });
        }


        [AllowAnonymous]
        [HttpPost]
        public async Task<IActionResult> MailValidate(ConfirmMailForAccountModel input, [FromServices] IOptions<LoginSettings> loginOptions, [FromQuery] string? returnUrl = null)
        {
            ViewBag.ReturnUrl = returnUrl;
            if (!ModelState.IsValid)
                return View();
            string? username = await _UserManager.ExtractUserFromTokenForMailValidationAndCheck(input.Token, input.ValidationCode);
            if (username == null)
                return View("mailtokenexpired");
            if (User.Identity.IsAuthenticated && !User.Identity.Name.Equals(input.UserName, System.StringComparison.InvariantCultureIgnoreCase))
            {
                return View("mailvalidatemismatch");
            }

            if (!username.Equals(input.UserName, StringComparison.InvariantCultureIgnoreCase))
                return NotFound();

            var profile = await _UserManager.GetProfileByName(username);
            if (profile == null)
                return NotFound();

            switch (await _UserManager.ValidateUserPassword(username, input.Password))
            {
                case UserLoginStep1Result.Success:  // we are done...
                    await _UserManager.SetMailValidated(username, input.ValidationCode);
                    var signin = await _UserManager.CreatePrincipal(profile.Name, false);
                    if (signin != null)
                        await HttpContext.SignInAsync(signin);
                    return RedirectToAction("Index", "Home");
                case UserLoginStep1Result.SetupFactorTwo:   // we need to capture factor #2...
                    await _UserManager.SetMailValidated(username, input.ValidationCode);
                    return View("setupfactortwo", new Setup2FAModel() { UserName = username, Parameters = await _UserManager.GetNew2FAChallenge(username), Token = await _UserManager.GetPageForwardToken(username) });
                case UserLoginStep1Result.ForceNewPassword:
                    await _UserManager.SetMailValidated(username, input.ValidationCode);
                    return View("forcepasswordchange", new ForcePasswordChangeModel() { UserName = username, Token = await _UserManager.GetPageForwardToken(username) });
                case UserLoginStep1Result.GetFactorTwo:
                    await _UserManager.SetMailValidated(username, input.ValidationCode);
                    return View("promptfactortwo", new LoginModel2FA() { UserName = username, LoginToken = await _UserManager.GetPageForwardToken(username) });
                default:
                    await Task.Delay((Random.Shared.Next(4) + 1) * 500);    // slow down...
                    ModelState.AddModelError(string.Empty, "The username/password combination doesn't validate. Please try again!");
                    return View(new ConfirmMailForAccountModel() { EMail = profile.ContactEMail, UserName = username, ValidationCode = input.ValidationCode, Token = input.Token });
            }
        }

        [AllowAnonymous]
        [HttpPost]
        public async Task<IActionResult> Confirm2FA(Setup2FAModel input, [FromQuery] string? returnUrl = null)
        {
            ViewBag.ReturnUrl = returnUrl;
            if (!ModelState.IsValid)
                return View();
            if (!await _UserManager.ValidatePageForwardToken(input.UserName, input.Token))
                return NotFound();

            if (await _UserManager.ValidateUser2FA(input.UserName, input.Code))
            {
                await _UserManager.Confirm2FASetup(input.UserName);
                var signin = await _UserManager.CreatePrincipal(input.UserName, true);
                if (signin != null)
                    await HttpContext.SignInAsync(signin);
                return RedirectToAction("Index", "Home");
            }
            else
            {
                await Task.Delay((Random.Shared.Next(4) + 1) * 500);    // slow down...

                ModelState.AddModelError(nameof(input.Code), "Invalid code. Please try again...");
            }

            ModelState.Remove(nameof(input.Token));
            ModelState.Remove(nameof(input.Code));
            return View("setupfactortwo", new Setup2FAModel() { UserName = input.UserName, Parameters = await _UserManager.GetNew2FAChallenge(input.UserName), Token = await _UserManager.GetPageForwardToken(input.UserName) });
        }

        [AllowAnonymous]
        [HttpPost]
        public async Task<IActionResult> ForcePasswordChange(ForcePasswordChangeModel input, [FromServices] IOptions<LoginSettings> loginOptions, [FromServices] PasswordChecker pwCheck, [FromQuery] string? returnUrl = null)
        {
            ViewBag.ReturnUrl = returnUrl;
            if (ModelState.IsValid)
            {
                bool LoginStep2 = false;
                if (!string.IsNullOrWhiteSpace(input.Token))
                {
                    if (!await _UserManager.ValidatePageForwardToken(input.UserName, input.Token))
                    {
                        ModelState.AddModelError(string.Empty, "The login process expired, please retry!");
                        return View("index", "login");
                    }
                }
                else
                {
                    var pw = await _UserManager.ValidateUserPassword(input.UserName, input.OldPassword);
                    // explicitly test for all valid combinations to find a failure...
                    if (pw != UserLoginStep1Result.Success && pw != UserLoginStep1Result.ForceNewPassword && pw != UserLoginStep1Result.GetFactorTwo && pw != UserLoginStep1Result.SetupFactorTwo)
                    {
                        await Task.Delay((Random.Shared.Next(4) + 1) * 500);    // slow down...
                        ModelState.AddModelError(string.Empty, "The username/password combination didn't validate, please try again!");
                        return View();
                    }
                }
                var result = await pwCheck.ValidatePassword(input.NewPassword);
                foreach (var item in result)
                    ModelState.AddModelError(nameof(SignUpModel.Password), item);
                if (ModelState.IsValid)
                {
                    // gotcha - all good.
                    var nextStep = await _UserManager.SetPassword(input.UserName, input.NewPassword);

                    switch (nextStep)
                    {
                        case UserLoginStep1Result.Success:  // we are done...
                            var signin = await _UserManager.CreatePrincipal(input.UserName, false);
                            if (signin != null)
                                await HttpContext.SignInAsync(signin);
                            return RedirectToAction("Index", "Home");
                        case UserLoginStep1Result.SetupFactorTwo:   // we need to capture factor #2...
                            return View("setupfactortwo", new Setup2FAModel() { UserName = input.UserName, Parameters = await _UserManager.GetNew2FAChallenge(input.UserName) });
                        case UserLoginStep1Result.ForceNewPassword:
                            // shouldn't happen?!
                            return View("forcepasswordchange", new ForcePasswordChangeModel() { UserName = input.UserName, Token = await _UserManager.GetPageForwardToken(input.UserName) });
                        case UserLoginStep1Result.GetFactorTwo:
                            return View("promptfactortwo", new LoginModel2FA() { UserName = input.UserName, LoginToken = await _UserManager.GetPageForwardToken(input.UserName) });
                        default:
                            await Task.Delay((Random.Shared.Next(4) + 1) * 500);    // slow down...
                            ModelState.AddModelError(string.Empty, "The username/password combination doesn't validate. Please try again!");
                            return View();
                    }
                }
            }

            await Task.Delay((Random.Shared.Next(4) + 1) * 500);    // slow down...
            return View();
        }


        [AllowAnonymous]
        [HttpPost]
        [ValidateCaptcha(ErrorMessage = "Please enter the security code as a number.",
                            CaptchaGeneratorLanguage = Language.English,
                            CaptchaGeneratorDisplayMode = DisplayMode.NumberToWord)]
        public async Task<IActionResult> Signup(SignUpModel input, [FromServices] PasswordChecker pwCheck, [FromServices] IOptions<LoginSettings> loginOptions, [FromQuery] string? returnUrl = null)
        {
            ViewBag.ReturnUrl = returnUrl;
            if (ModelState.IsValid)
            {
                var cfg = await _Settings.GetOrLoad();


                if (!input.AcceptToS)
                    ModelState.AddModelError(nameof(input.AcceptToS), "You must accept the Terms of Service to create an account!");
                var result = await pwCheck.ValidatePassword(input.Password);
                foreach (var item in result)
                    ModelState.AddModelError(nameof(SignUpModel.Password), item);
                if (ModelState.IsValid)
                {
                    if (await _UserManager.Exists(input.UserName))
                    {
                        ModelState.AddModelError(nameof(input.UserName), "Sorry, the selected user name already exists. Please use another one!");
                    }
                    else
                    {
                        var profile = await _UserManager.CreateUserFromSignup(input.UserName, input.EMail, input.Enable2FA, input.Password);
                        if (profile == null)
                            ModelState.AddModelError(string.Empty, "Unknown error in user creation. Please try again later!");
                        else
                        {
                            if (!profile.IsEnabled)
                            {
                                return View("adminvalidationpending");
                            }
                            if (profile.ContactEMail == null)
                            {
                                return View("mailvalidationpending");
                            }
                            // profile would be enabled and validated...
                            if (input.Enable2FA || loginOptions.Value.Require2FASignup)
                                return View("setup2fa", new Setup2FAModel() { UserName = profile.Name, Parameters = await _UserManager.GetNew2FAChallenge(profile.Id) });
                            else
                            {
                                var signin = await _UserManager.CreatePrincipal(profile.Name, false);
                                if (signin != null)
                                    await HttpContext.SignInAsync(signin);
                                return (string.IsNullOrWhiteSpace(returnUrl)) ? RedirectToAction("Index", "Home") : LocalRedirect(returnUrl);
                            }
                        }
                    }
                }
            }
            return View(new SignUpModel() { Requries2FA = loginOptions.Value.Require2FASignup });
        }

        [HttpPost]
        public async Task<IActionResult> ChangePassword(PasswordResetInput input, [FromServices] PasswordChecker pwCheck)
        {
            var sb = new System.Text.StringBuilder();
            var userProfile = await _UserManager.GetProfileByName(User.Identity.Name);
            if (userProfile == null || !userProfile.IsEnabled)
                return NotFound();  // somewhat critical...

            string? error = null;

            if (input.NewPassword != input.NewPasswordRetype)
                error = "Retyped password doesn't match!";
            else
            {
                var r = await _UserManager.ValidateUserPassword(userProfile.Name, input.CurrentPassword);
                if (r != UserLoginStep1Result.Success && r != UserLoginStep1Result.GetFactorTwo)    // TODO: eventually ask for 2FA for password change?
                    error = "Current password is incorrect!";
                else
                {

                    var result = await pwCheck.ValidatePassword(input.NewPassword);
                    foreach (var item in result)
                        sb.AppendLine(item);
                    if (sb.Length > 0)
                        error = sb.ToString();
                    else
                    {
                        var nextStep = await _UserManager.SetPassword(userProfile.Name, input.NewPassword);

                        switch (nextStep)
                        {
                            case UserLoginStep1Result.Success:  // we are done...
                                error = null;
                                break;
                            case UserLoginStep1Result.SetupFactorTwo:   // we need to capture factor #2...
                                return View("setupfactortwo", new Setup2FAModel() { UserName = userProfile.Name, Parameters = await _UserManager.GetNew2FAChallenge(userProfile.Name) });
                            case UserLoginStep1Result.ForceNewPassword:
                                // shouldn't happen?!
                                return View("forcepasswordchange", new ForcePasswordChangeModel() { UserName = userProfile.Name, Token = await _UserManager.GetPageForwardToken(userProfile.Name) });
                            case UserLoginStep1Result.GetFactorTwo:
                                return View("promptfactortwo", new LoginModel2FA() { UserName = userProfile.Name, LoginToken = await _UserManager.GetPageForwardToken(userProfile.Name) });
                            default:
                                await Task.Delay((Random.Shared.Next(4) + 1) * 500);    // slow down...
                                ModelState.AddModelError(string.Empty, "The username/password combination doesn't validate. Please try again!");
                                return View();
                        }
                    }
                }
            }
            return View("index-security", new ProfileSecurityInfo() { IsMFAEnabled = await _UserManager.IsMFAEnabled(userProfile.Name), PasswordChangeError = error, PasswordChanged = error == null });

        }

        [HttpPost]
        public async Task<IActionResult> CreateToken(NewTokenInputDto values)
        {
            if (ModelState.IsValid)
            {
                var result = await _UserManager.CreateToken(
                    User.Identity.Name,
                    values.Name,
                    values.MakeSiteAdmin,
                    values.MakeUserAdmin,
                    values.MakeModerator,
                    values.MakeContentManager,
                    values.Expires
                );
                if (result != null)
                    return View("new-token-result", new CreatedTokenInfoDto(result));
            }
            return RedirectToAction("index", new { id = "tokens" });
        }

    }
}