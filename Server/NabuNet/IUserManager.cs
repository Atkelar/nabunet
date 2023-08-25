using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Mvc;

namespace NabuNet
{
    public interface IUserManager
    {
        Task<UserProfile?> GetProfileByName(string username);
        Task<UserLoginStep1Result> ValidateUserPassword(string username, string password);
        Task<bool> ValidateUser2FA(string username, string response);
        Task<UserProfile?> CreateUserFromSignup(string username, string eMail, bool enable2FA, string password);
        Task<Setup2FAParameters?> GetNew2FAChallenge(string username);

        Task<bool> SendMailValidationMessage(string username, string newEMail);
        Task<bool> Exists(string username);
        Task<string?> ExtractUserFromTokenForMailValidationAndCheck(string token, string code);

        Task<string> GetPageForwardToken(string username);
        Task<bool> ValidatePageForwardToken(string username, string token);
        Task<UserLoginStep1Result> SetPassword(string username, string newPassword, bool focePasswordChange = false);
        Task SetMailValidated(string username, string code);
        Task Confirm2FASetup(string username);
        Task UpdateProfileByName(string username, string displayName, string highScoreName, bool allowAPIAccess, bool allowDeviceAccess);
        Task StartEMailUpdate(string username, string eMailAddress);
        Task<bool> IsMFAEnabled(string username);
        Task<bool> ApproveUser(string userName);
        Task<IEnumerable<string>> GetUserNames();
        Task<IEnumerable<TokenInfo>> GetTokensForUser(string name);
        Task<CreatedTokenInfo?> CreateToken(string username, string? name, bool enableSiteAdmin, bool enableUserAdmin, bool enableModerator, bool enableContentAdmin, DateTime? expires = null);

        Task<System.Security.Claims.ClaimsPrincipal?> CreatePrincipal(string username, bool was2fa, TokenInfo? fromToken = null);
        Task<(string username, TokenInfo token)?> GetValidatedToken(string tokenInput);
        Task DeleteUserToken(string username, Guid tokenId);
    }
}