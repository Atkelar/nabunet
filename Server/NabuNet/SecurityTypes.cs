using System.IO;
using System.Security.Claims;

namespace NabuNet
{
    internal static class SecurityTypes
    {
        public const string RoleAdministrator = "admin";
        public const string RoleContentManager = "cmgr";
        public const string RoleModerator = "mod";
        public const string RoleUserAdmin = "uadm";

        public const string UserTypeClaim = "utype";
        public const string UserTypeUser = "user";
        public const string UserTypeGuest = "guest";

        public const string LoginTypeClaim = "ltp";
        public const string LoginTypeApi = "api";
    }
}