namespace NabuNet
{
    internal class SecurityPolicy
    {
        // full user only access; i.e. no guest or temp users allowed
        public const string User = "user";
        // any valid login from our system is allowed
        public const string Any = "any";
        // user admin privilege required.
        public const string UserAdmin = "uadm";
        // Only valid admins are allowed. Since admins are users, this includes "user"
        public const string SiteAdmin = "admin";
        public const string Moderator = "mod";
        public const string ContentManager = "cmg";
    }
}