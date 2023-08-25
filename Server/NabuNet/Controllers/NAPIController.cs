using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.Net;
using System.Threading.Tasks;
using ICSharpCode.SharpZipLib.Zip;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using NabuNet.Models;
using NabuNet.ProgramModel;

namespace NabuNet
{
    /// <summary>
    /// The NabuNet API endpoint. Paths are called "/napi/" becuase the usual "/api/" is used by the modem communication.
    /// </summary>
    [ApiController()]
    [Route("napi/v1")]  // path is "napi" becuase "api" is the websocket endpoint for the modem!
    public class NAPIController
        : ControllerBase
    {
        public NAPIController(ILogger<NAPIController> logger, IServerConfigFactory settings)
        {
            _Settings = settings;
            _Logger = logger;
        }
        public const byte ApiVersionLevel = 1;
        private readonly IServerConfigFactory _Settings;
        private readonly ILogger _Logger;

        /// <summary>
        /// Returns general server information about enabled or disabled features and settings.
        /// </summary>
        [HttpGet("info")]
        public async Task<ProtocolInfoDto> GetInfo()
        {
            var cfg = await _Settings.GetOrLoad();
            return new ProtocolInfoDto()
            {
                ApiVersion = ApiVersionLevel,
                SupportsGuest = cfg.EnableGustAccess,
                GuestTimeout = cfg.GuestSessionTimeout.Minutes,
                ServerVersion = $"{this.GetType().Assembly.GetName().Name} {this.GetType().Assembly.GetName().Version} ({ApiVersionLevel})",
                SupportsVirtualServers = cfg.EnableVirtualServers,
                SupportsLogin = cfg.EnableLogin,
                TagLine = cfg.ServerTagLine,
                Name = cfg.ServerName
            };
        }

        /// <summary>
        /// Fetches the current server announcement; This is a title and message text that will be shown on the home page and on possible error message pages. Should be used for maintenance announcements.
        /// </summary>
        /// <param name="raw">True to return the raw markdown text of the article, if any, false to return the plain text version instead.</param>
        [HttpGet("announcement")]
        [ProducesResponseType(StatusCodes.Status200OK)]
        [ProducesResponseType(StatusCodes.Status204NoContent)]
        public async Task<ActionResult<BaseArticle>> GetAnnouncement([FromQuery] bool raw = false)
        {
            var cfg = await _Settings.GetOrLoad();
            var msg = cfg.ServerMessage;
            if (msg == null)
                return NoContent();
            return new BaseArticle()
            {
                Title = msg.Title,
                Created = msg.Created,
                Article = raw ? msg.Article : Markdig.Markdown.ToPlainText(msg.Article),
                ReferenceDate = msg.ReferenceDate
            };
        }

        /// <summary>
        /// Updates/sets the server status message/article.
        /// </summary>
        /// <param name="raw">True to return the raw markdown text of the article, if any, false to return the plain text version instead.</param>
        [HttpPost("announcement")]
        [Authorize(SecurityPolicy.SiteAdmin)]
        [ProducesResponseType(StatusCodes.Status200OK)]
        public async Task<ActionResult<BaseArticle>> SetAnnouncement([FromBody] ArticleInputDto input, [FromQuery] bool raw = false)
        {
            var cfg = await _Settings.GetOrLoad();
            await cfg.SetServerMessage(input.Title, input.Article, input.ReferenceDate);
            var msg = cfg.ServerMessage;

            if (msg == null)
                return NoContent();
            return new BaseArticle()
            {
                Title = msg.Title,
                Created = msg.Created,
                Article = raw ? msg.Article : Markdig.Markdown.ToPlainText(msg.Article),
                ReferenceDate = msg.ReferenceDate
            };
        }

        /// <summary>
        /// Removes the server announcement.
        /// </summary>
        [HttpDelete("announcement")]
        [Authorize(SecurityPolicy.SiteAdmin)]
        [ProducesResponseType(StatusCodes.Status204NoContent)]
        public async Task<ActionResult> ClearAnnouncement()
        {
            var cfg = await _Settings.GetOrLoad();
            await cfg.ClearServerMessage();
            return NoContent();
        }

        /// <summary>
        /// Initialize the server, based on a pre-shared secret put into the server configuration. For obvious security implications, this will only work once and is thus hidden from the API endpoint.
        /// </summary>
        [ApiExplorerSettings(IgnoreApi = true)]
        [HttpPost("serverbootstrapnow")]
        [AllowAnonymous]
        public async Task<ActionResult<bool>> ServerBootstrapNow(BootstrapParameters input)
        {
            return false;
        }

        /// <summary>
        /// Resets the e-mail address for an existing user account. Note that this requires admin 
        /// privileges and will send out the proper mail change messages too, so that the new e-mail 
        /// MUST be confirmed by the receiver within the mail token timeout!
        /// </summary>
        /// <param name="newMailAddress">The new e-mail address to use.</param>
        /// <param name="userName">The name of th euser to modify.</param>
        /// <returns>The result will be true if the change was initiated successuflly.</returns>
        [HttpPut("resetusermail/{userName}")]
        [Authorize(SecurityPolicy.UserAdmin)]
        [ProducesResponseType(StatusCodes.Status200OK)]
        [ProducesResponseType(StatusCodes.Status204NoContent)]
        [ProducesResponseType(StatusCodes.Status404NotFound)]
        public async Task<ActionResult<bool>> ResetUserMail([FromBody] string newMailAddress, [FromRoute] string userName, [FromServices] IUserManager users)
        {
            if (!await users.Exists(userName))
                return NotFound();

            return await users.SendMailValidationMessage(userName, newMailAddress);
        }

        /// <summary>
        /// Approve a pending user account. If the a-mail validation is still pending, this will also send out the appropriate link.
        /// </summary>
        /// <param name="userName">The name of the account.</param>
        /// <param name="users">*internal*</param>
        /// <returns>True if the approve has been successful.</returns>
        [HttpPut("approveaccount/{userName}")]
        [Authorize(SecurityPolicy.UserAdmin)]
        [ProducesResponseType(StatusCodes.Status200OK)]
        [ProducesResponseType(StatusCodes.Status204NoContent)]
        [ProducesResponseType(StatusCodes.Status404NotFound)]
        public async Task<ActionResult<bool>> ApproveAccount([FromRoute] string userName, [FromServices] IUserManager users)
        {
            if (!await users.Exists(userName))
                return NotFound();

            return await users.ApproveUser(userName);
        }


        /// <summary>
        /// Get the list of all user names...
        /// </summary>
        /// <param name="users">*internal*</param>
        /// <returns>True if the approve has been successful.</returns>
        [HttpGet("accounts")]
        [Authorize(SecurityPolicy.UserAdmin)]
        [ProducesResponseType(StatusCodes.Status200OK)]
        [ProducesResponseType(StatusCodes.Status204NoContent)]
        public async Task<ActionResult<IEnumerable<string>>> GetUserNames([FromServices] IUserManager users)
        {
            return new ActionResult<IEnumerable<string>>(await users.GetUserNames());
        }

        /// <summary>
        /// Creates a (short term) bearer token from an API token.
        /// </summary>
        /// <param name="token">The issued token for the user.</param>
        /// <param name="users">**internal**</param>
        /// <returns>The bearer token value for API access. Usually only valid for a few minutes, be sure to refresh soon!</returns>
        [HttpPost("login")]
        [AllowAnonymous()]
        [ProducesResponseType(StatusCodes.Status200OK)]
        [ProducesResponseType(StatusCodes.Status404NotFound)]
        [ProducesResponseType(StatusCodes.Status403Forbidden)]
        public async Task<ActionResult<LoginTokenResult>> LoginApi([FromBody] RequestTokenInput token, [FromServices] IUserManager users, [FromServices] ApiTokenSigner signer)
        {
            var info = await users.GetValidatedToken(token.Token);
            if (!info.HasValue)
                return NotFound();

            var principal = await users.CreatePrincipal(info.Value.username, false, info.Value.token);

            if (principal == null || principal.Identity == null)
                return Forbid();

            DateTime? expires;
            var tokenResult = signer.CreateSignedToken((System.Security.Claims.ClaimsIdentity)principal.Identity, out expires);

            if (tokenResult == null || !expires.HasValue)
                return NotFound();
            return new LoginTokenResult() { Token = tokenResult, ValidUntil = expires.Value };
        }

        /// <summary>
        /// Takes a NabuNet package file (ZIP) and puts it into the program repository based on the manifest file
        /// contained within. The result is the new assigned ID inside that repository. This ID can be used to 
        /// refer back to the asset in virtual server content listings or similar features. Requires "Content Manager" permission.
        /// </summary>
        /// <param name="packetInput">The content of the ZIP file.</param>
        /// <param name="assets">*internal*</param>
        /// <returns>The new Asset ID</returns>
        [Authorize(SecurityPolicy.ContentManager)]
        [HttpPost("asset/deploy")]
        [ProducesResponseType(StatusCodes.Status200OK)]
        [ProducesResponseType(StatusCodes.Status400BadRequest)]
        public async Task<ActionResult<int?>> DeployAsset([FromBody] string packetInput, [FromServices] IAssetManager assets)
        {
            byte[] packet = System.Convert.FromBase64String(packetInput);
            using (var zipFile = new System.IO.MemoryStream(packet, false))
            {
                try
                {
                    var info = await assets.CreateAssetFromBlob(zipFile);
                    return info.Id;
                }
                catch (InvalidAssetDefinitionException ex)
                {
                    return ValidationProblem(ex.Message, null, 400, "Asset validation failed", null, null);
                }
            }
        }



        [Authorize(SecurityPolicy.ContentManager)]
        [HttpPut("vserver/{id}/update")]
        [ProducesResponseType(StatusCodes.Status200OK)]
        [ProducesResponseType(StatusCodes.Status400BadRequest)]
        public async Task<ActionResult<VirtualServerDetails>> UpdateVirtualServerDetails(
            [FromServices] IVirtualServerManager servers,
            [FromServices] IUserManager users,
            [FromRoute][RegularExpression(@"^[0-9A-F]{5}$")] string id,
            [FromQuery] int? newKernelAsset = null,
            [FromQuery] int? newLoaderAsset = null,
            [FromQuery] string? newName = null,
            [FromQuery] string? newOwner = null,
            [FromQuery] bool? enabled = null
            )
        {
            // content manager permission is validated by ASP.NET

            int code = (int.Parse(id, System.Globalization.NumberStyles.HexNumber) >> 4) & 0xFFFF;

            if (NabuUtils.ChannelCodeFromNumber(code) != id)
                return NotFound();


            var details = await servers.GetDetails(code, false);

            if (details == null)
                return NotFound();

            if (newOwner != null)
            {
                var profile = await users.GetProfileByName(newOwner);
                if (profile == null || !profile.IsEnabled || profile.ContactEMail == null)
                    ValidationProblem("New owner not found or inactive!", null, 400, "Validation failed", null, null);

                if (details.Info.Owner != newOwner)
                {
                    await servers.UpdateOwner(code, newOwner);
                }
            }

            if (newName != null)
            {
                if (newName != details.Info.Name)
                {
                    await servers.UpdateName(code, newName);
                }
            }

            if (enabled.HasValue && enabled.Value != details.Info.IsActive)
            {
                await servers.SetEnabled(code, enabled.Value);
            }

            if (newKernelAsset.HasValue && newKernelAsset.Value != details.Kernel)
            {
                await servers.SetKernelAsset(code, newKernelAsset.Value);
            }

            if (newLoaderAsset.HasValue && newLoaderAsset.Value != details.Loader)
            {
                await servers.SetLoaderAsset(code, newLoaderAsset.Value);
            }

            details = await servers.GetDetails(code, false);
            if (details == null)    // shouldn't happen, mostly to calm down the compiler null-checks.
                return NotFound();
            return details;
        }


    }
}