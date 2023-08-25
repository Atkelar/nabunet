using Microsoft.AspNetCore.Mvc;

namespace NabuNet
{
    /// <summary>
    /// Base class for MVC controllers related to UI production. Contains some helpers for permission checking and forwarding to views.
    /// </summary>
    public abstract class NabuControllerBase
        : Controller
    {
        private void AddPermissionFlags()
        {
            this.ViewBag.ShowAdmin = (this.User?.IsInRole(SecurityTypes.RoleAdministrator) ?? false) || (this.User?.IsInRole(SecurityTypes.RoleUserAdmin) ?? false);
            this.ViewBag.ShowSiteAdmin = this.User?.IsInRole(SecurityTypes.RoleAdministrator) ?? false;
            this.ViewBag.ShowUserAdmin = this.User?.IsInRole(SecurityTypes.RoleUserAdmin) ?? false;
            this.ViewBag.ShowModerator = this.User?.IsInRole(SecurityTypes.RoleModerator) ?? false;
            this.ViewBag.ShowContentManager = this.User?.IsInRole(SecurityTypes.RoleContentManager) ?? false;
        }

        public override ViewResult View()
        {
            AddPermissionFlags();
            return base.View();
        }
        public override ViewResult View(object? model)
        {
            AddPermissionFlags();
            return base.View(model);
        }
        public override ViewResult View(string? viewName)
        {
            AddPermissionFlags();
            return base.View(viewName);
        }
        public override ViewResult View(string? viewName, object? model)
        {
            AddPermissionFlags();
            return base.View(viewName, model);
        }
    }
}