using System;
using System.IO;
using System.Threading.Tasks;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;

namespace NabuNet
{
    public class ServerConfig
    {
        private readonly ILogger<ServerConfig> _Logger;
        private readonly IDatabase _Database;
        private readonly IOptionsMonitor<ServerSettings> _Settings;

        public ServerConfig(ILogger<ServerConfig> logger, IDatabase database, IOptionsMonitor<ServerSettings> settings)
        {
            _Logger = logger;
            _Database = database;
            _Settings = settings;
        }

        private string? _ServerName;
        private string? _ServerTagLine;
        private bool _EnableGustAccess;
        private TimeSpan _GuestSessionTimeout = TimeSpan.FromHours(1);
        private bool _EnableLogin;
        private bool _EnableVirtualServers;
        private bool _IsReadOnly;
        private bool _EnableNewUsers;
        private bool _EnableSignup;
        private bool _RequireMailValidation;
        private int? _TZOffset;
        private string? _TimeFormat;
        private bool? _UseLocalTime;

        // most settings are forwarded from the hard server config and need to agree for security reasons.
        // Note that this object might also hold additional settings eventually! This is why we don't use the same base class.
        public string ServerName { get => _ServerName ?? _Settings.CurrentValue.ServerName; }
        public string ServerTagLine { get => _ServerTagLine ?? _Settings.CurrentValue.ServerTagLine; }
        public bool EnableGustAccess { get => _EnableGustAccess && _Settings.CurrentValue.EnableGustAccess; }
        public TimeSpan GuestSessionTimeout { get => _Settings.CurrentValue.GuestSessionTimeout < _GuestSessionTimeout ? _Settings.CurrentValue.GuestSessionTimeout : _GuestSessionTimeout; }
        public bool EnableLogin { get => _EnableLogin && _Settings.CurrentValue.EnableLogin; }

        public bool RequireMailValidation { get => _RequireMailValidation || _Settings.CurrentValue.RequireMailValidation; }

        public bool IsReadOnly { get => _IsReadOnly || _Settings.CurrentValue.ReadOnlyMode; }
        public bool EnableVirtualServers { get => _EnableVirtualServers && _Settings.CurrentValue.EnableVirtualServers; }
        public bool IsLoaded { get; private set; }

        // auto-enable new users. If false, an admin needs to manually enable them...
        public bool EnableNewUsers { get => _EnableNewUsers && _Settings.CurrentValue.EnableNewUsers; }

        // Enable new user signup...
        public bool EnableSignup { get => _EnableSignup && _Settings.CurrentValue.EnableSignup; }

        public int TZOffset { get => _TZOffset ?? _Settings.CurrentValue.TZOffset; }
        public string TimeFormat { get => _TimeFormat ?? _Settings.CurrentValue.TimeFormat; }
        public bool UseServerLocalTime { get => _UseLocalTime ?? _Settings.CurrentValue.UseLocalTime; }

        private class ConfigSerializer
        {
            public string? ServerName { get; set; }
            public string? ServerTagLine { get; set; }
            public bool EnableGustAccess { get; set; }
            public TimeSpan GuestSessionTimeout { get; set; } = TimeSpan.FromHours(1);
            public bool EnableLogin { get; set; }
            public bool EnableVirtualServers { get; set; }
            public bool IsReadOnly { get; set; }
            public bool EnableNewUsers { get; set; }
            public bool EnableSignup { get; set; }
            public bool RequireMailValidation { get; set; }
            // 0 => UTC, any other = minutes offset.
            public int? TZOffset { get; set; }
            public bool? UseServerLocalTime { get; set; }
            public string? TimeFormat { get; set; }
        }

        public async Task UpdateSettings(
                string? servername,
                string? serverTagLine,
                bool? enableGuestAccess,
                bool? enableLogin,
                bool? enableVirtualServers,
                TimeSpan? guestSessionTimeout,
                bool? isReadOnly,
                bool? enableSignup,
                bool? enableNewUsers,
                bool? requireMailValidation,
                string? timeFormat,
                int? tzOffset,
                bool? useServerTime)
        {
            if (servername != null)
                _ServerName = servername;
            if (serverTagLine != null)
                _ServerTagLine = serverTagLine;
            if (enableGuestAccess.HasValue)
                _EnableGustAccess = enableGuestAccess.Value;
            if (enableLogin.HasValue)
                _EnableLogin = enableLogin.Value;
            if (enableVirtualServers.HasValue)
                _EnableVirtualServers = enableVirtualServers.Value;
            if (isReadOnly.HasValue)
                _IsReadOnly = isReadOnly.Value;
            if (enableNewUsers.HasValue)
                _EnableNewUsers = enableNewUsers.Value;
            if (enableSignup.HasValue)
                _EnableSignup = enableSignup.Value;
            if (requireMailValidation.HasValue)
                _RequireMailValidation = requireMailValidation.Value;
            if (timeFormat != null)
                _TimeFormat = timeFormat;
            if (tzOffset != null)
                _TZOffset = tzOffset.Value;
            if (useServerTime.HasValue)
                _UseLocalTime = useServerTime.Value;

            var settings = new ConfigSerializer()
            {
                EnableGustAccess = _EnableGustAccess,
                EnableLogin = _EnableLogin,
                EnableVirtualServers = _EnableVirtualServers,
                GuestSessionTimeout = _GuestSessionTimeout,
                ServerName = _ServerName,
                ServerTagLine = _ServerTagLine,
                IsReadOnly = _IsReadOnly,
                EnableNewUsers = _EnableNewUsers,
                EnableSignup = _EnableSignup,
                RequireMailValidation = _RequireMailValidation,
                TZOffset = _TZOffset,
                UseServerLocalTime = _UseLocalTime,
                TimeFormat = _TimeFormat
            };
            await _Database.SetSingleDocumentAsync<ConfigSerializer>(SettingDocumentName, settings);
            await _Database.FlushAsync();
        }

        private const string SettingDocumentName = "server_settings";
        private const string ServerMessageDocumentName = "server_message";

        private const string ImprintDocumentName = "server_imprint";

        public async Task ReloadSettings()
        {
            var settings = await _Database.GetSingleRequiredDocumentAsync<ConfigSerializer>(SettingDocumentName);
            // we could load something...
            _EnableGustAccess = settings.EnableGustAccess;
            _EnableLogin = settings.EnableLogin;
            _EnableVirtualServers = settings.EnableVirtualServers;
            _GuestSessionTimeout = settings.GuestSessionTimeout;
            _ServerName = settings.ServerName;
            _ServerTagLine = settings.ServerTagLine;
            _IsReadOnly = settings.IsReadOnly;
            _EnableSignup = settings.EnableSignup;
            _EnableNewUsers = settings.EnableNewUsers;
            _RequireMailValidation = settings.RequireMailValidation;

            ServerMessage = await _Database.GetSingleDocumentAsync<Models.BaseArticle>(ServerMessageDocumentName);
            Imprint = await _Database.GetSingleDocumentAsync<Models.BaseArticle>(ImprintDocumentName);
            IsLoaded = true;
        }

        public Models.BaseArticle? ServerMessage { get; private set; }
        public Models.BaseArticle? Imprint { get; private set; }

        public string BaseUrl { get => _Settings.CurrentValue.BaseUrl; }

        public async Task SetServerMessage(string title, string article, DateTime? referenceDate)
        {
            _Logger.LogInformation("Updating server status message: {title}", title);
            ServerMessage = new Models.BaseArticle()
            {
                Created = DateTime.UtcNow,
                Title = title,
                Article = article,
                ReferenceDate = referenceDate
            };
            await _Database.SetSingleDocumentAsync(ServerMessageDocumentName, ServerMessage);
            await _Database.FlushAsync();   // important, make sure we keep it!
        }

        public async Task ClearServerMessage()
        {
            _Logger.LogInformation("Removing server status message");
            ServerMessage = null;
            await _Database.RemoveSingleDocumentAsync(ServerMessageDocumentName);
            await _Database.FlushAsync();   // important, make sure we keep it!
        }

        public async Task SetImprint(string title, string content)
        {
            _Logger.LogInformation("Updating server imprint: {title}, {content}", title, content);
            Imprint = new Models.BaseArticle()
            {
                Created = DateTime.UtcNow,
                Title = title,
                Article = content
            };
            await _Database.SetSingleDocumentAsync(ImprintDocumentName, Imprint);
            await _Database.FlushAsync();   // important, make sure we keep it!
        }

        public async Task ClearImprint()
        {
            _Logger.LogInformation("Removing server imprint!");
            Imprint = null;
            await _Database.RemoveSingleDocumentAsync(ImprintDocumentName);
            await _Database.FlushAsync();   // important, make sure we keep it!
        }

        public DateTimeOffset GetServerTime()
        {
            DateTimeOffset now;
            if (UseServerLocalTime)
            {
                now = DateTimeOffset.Now;
            }
            else
            {
                now = new DateTimeOffset(DateTime.UtcNow, TimeSpan.FromMinutes(TZOffset));
            }
            return now;
        }

        // centralized date/time formatting code; this will be used any time a date/time is presented to a user to - eventually - enable "personal" timezone info.
        public string GetFormattedTime(DateTime value, bool inlcudeTimeZone)
        {
            if (UseServerLocalTime)
                return GetFormattedTime(new DateTimeOffset(value.ToLocalTime(), TimeSpan.Zero), inlcudeTimeZone);
            else
                return GetFormattedTime(new DateTimeOffset(value.ToUniversalTime(), TimeSpan.FromMinutes(TZOffset)), inlcudeTimeZone);
        }

        public string GetFormattedTime(DateTimeOffset value, bool inlcudeTimeZone)
        {
            if (inlcudeTimeZone)
                return value.ToString(TimeFormat) + value.ToString(" (K)");
            else
                return value.ToString(TimeFormat);
            // " (" + (TZOffset == 0 ? "UTC" : ((TZOffset > 0 ? "+" : "-") + (Math.Abs(TZOffset) / 60).ToString("0") + ":" + (Math.Abs(TZOffset) % 60).ToString("00"))) + ")";
        }

        public string GetFormattedServerTime(bool inlcudeTimeZone)
        {
            return GetFormattedTime(GetServerTime(), inlcudeTimeZone);
        }

        public class PlainDoucmentHelper
        {
            public DateTime UpdatedAt { get; set; }
            public string UpdatedBy { get; set; }
            public string Content { get; set; }
        }

        internal async Task<string> GetPrivacyPolicy()
        {
            PlainDoucmentHelper? doc = await _Database.GetSingleDocumentAsync<PlainDoucmentHelper>("privacy");
            if (doc == null)
            {
                string stubPath = System.IO.Path.Combine(System.Environment.CurrentDirectory, "stubtemplates", "privacy.md");
                if (File.Exists(stubPath))
                {
                    doc = new PlainDoucmentHelper()
                    {
                        Content = await File.ReadAllTextAsync(stubPath),
                        UpdatedAt = System.DateTime.UtcNow,
                        UpdatedBy = ""
                    };
                    await _Database.SetSingleDocumentAsync("privacy", doc);
                }
            }
            if (doc != null)
                return doc.Content;
            return "# policy not set!";
        }

        internal async Task<string> GetTermsOfService()
        {
            PlainDoucmentHelper? doc = await _Database.GetSingleDocumentAsync<PlainDoucmentHelper>("tos");
            if (doc == null)
            {
                string stubPath = System.IO.Path.Combine(System.Environment.CurrentDirectory, "stubtemplates", "tos.md");
                if (File.Exists(stubPath))
                {
                    doc = new PlainDoucmentHelper()
                    {
                        Content = await File.ReadAllTextAsync(stubPath),
                        UpdatedAt = System.DateTime.UtcNow,
                        UpdatedBy = ""
                    };
                    await _Database.SetSingleDocumentAsync("tos", doc);
                }
            }
            if (doc != null)
                return doc.Content;
            return "# policy not set!";
        }
    }
}