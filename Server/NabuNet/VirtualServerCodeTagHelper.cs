using System;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Razor.TagHelpers;

namespace NabuNet
{
    [HtmlTargetElement("vserver")]
    public class VirtualServerCodeTagHelper
        : TagHelper
    {
        public int Code { get; set; }
        public override async Task ProcessAsync(TagHelperContext context, TagHelperOutput output)
        {
            string fullCode = NabuUtils.ChannelCodeFromNumber(Code);
            output.TagName = "a";
            output.Attributes.SetAttribute("href", $"Servers/Details/{fullCode}");

            output.Content.Append(fullCode);
        }
    }
}