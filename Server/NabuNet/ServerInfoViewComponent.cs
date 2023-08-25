using System.Threading.Tasks;
using Microsoft.AspNetCore.Mvc;

namespace NabuNet
{
    public class ServerInfoViewComponent
        : ViewComponent
    {
        private readonly IServerConfigFactory _config;

        public ServerInfoViewComponent(IServerConfigFactory config)
        {
            _config = config;
        }
        public async Task<IViewComponentResult> InvokeAsync()
        {
            var cfg = await _config.GetOrLoad();
            return View("HeadLine", cfg);
        }


    }
}