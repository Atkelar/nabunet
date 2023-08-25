using System;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Razor.TagHelpers;

namespace NabuNet
{
    [HtmlTargetElement("li")]
    public class ActiveLinkTagHelper
        : TagHelper
    {
        public ActiveLinkTagHelper()
        {
        }

        public bool? NavActive { get; set; }

        public override async Task ProcessAsync(TagHelperContext context, TagHelperOutput output)
        {
            if (NavActive.HasValue) // *are* we enabled at all?
            {
                if (NavActive.Value)
                    output.Attributes.SetAttribute("class", "active");
                // if (NavActive.Value)
                // {
                //     output.Attributes.SetAttribute("href", "#");
                //     output.Attributes.SetAttribute("class", "nav-link active");
                //     output.Attributes.SetAttribute("aria-current", "page");
                // }
                // else
                // {
                //     output.Attributes.SetAttribute("class", "nav-link");
                // }
            }
        }
    }
}