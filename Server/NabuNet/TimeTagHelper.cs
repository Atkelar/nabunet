using System;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Razor.TagHelpers;

namespace NabuNet
{
    public class TimeTagHelper
        : TagHelper
    {
        private readonly IServerConfigFactory _settings;

        public DateTime? Relative { get; set; }
        public DateTime? Absolute { get; set; }
        public bool IncludeTimeZone { get; set; }
        public TimeTagHelper(IServerConfigFactory settings)
        {
            _settings = settings;
        }
        public override async Task ProcessAsync(TagHelperContext context, TagHelperOutput output)
        {
            if (Absolute.HasValue)
            {
                var cfg = await _settings.GetOrLoad();
                output.Content.Append(cfg.GetFormattedTime(Absolute.Value, IncludeTimeZone));
            }
            else
            {
                if (!Relative.HasValue)
                    output.Content.Append("not set");
                else
                {
                    var now = DateTime.UtcNow;
                    var diff = Relative.Value.Subtract(now).Duration();
                    if (diff.TotalMinutes < 1)
                        output.Content.Append("is now");
                    else
                    {
                        if (now > Relative.Value)
                            output.Content.Append("was ");
                        else
                            output.Content.Append("will be in ");

                        if (diff.TotalDays > 0)
                            output.Content.AppendFormat("{0:0} days, ", diff.TotalDays);
                        if (diff.Hours > 0)
                            output.Content.AppendFormat("{0:0} hours, ", diff.Hours);
                        output.Content.AppendFormat("{0:0} minutes", diff.Minutes);
                        if (now > Relative.Value)
                            output.Content.Append(" ago");
                    }
                }
            }
        }
    }
}