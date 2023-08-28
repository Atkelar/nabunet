using System.IO;
using System.Threading.Tasks;
using Captcha.Core;
using Microsoft.AspNetCore.Authentication.Cookies;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.DataProtection;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;

namespace NabuNet
{
    public class Program
    {
        public static async Task Main(string[] args)
        {
            var builder = WebApplication.CreateBuilder(args);

            // Add services to the container.
            builder.Services
                .AddControllersWithViews();

            var signer = new ApiTokenSigner(builder.Configuration["apitokensigningkey"]);
            builder.Services.AddSingleton<ApiTokenSigner>(signer);
            builder.Services.AddControllers();
            builder.Services.AddEndpointsApiExplorer();
            builder.Services.AddSwaggerGen(
                options =>
                {
                    options.AddSecurityDefinition(JwtBearerDefaults.AuthenticationScheme,
                    new Microsoft.OpenApi.Models.OpenApiSecurityScheme()
                    {
                        Name = "Authorization",
                        Type = Microsoft.OpenApi.Models.SecuritySchemeType.ApiKey,
                        Description = "You can get tokens from the user profile page!",
                        In = Microsoft.OpenApi.Models.ParameterLocation.Header,
                        Scheme = JwtBearerDefaults.AuthenticationScheme
                    });
                    options.AddSecurityRequirement(new Microsoft.OpenApi.Models.OpenApiSecurityRequirement
                    {
                        {
                            new Microsoft.OpenApi.Models.OpenApiSecurityScheme()
                            {
                                Name = JwtBearerDefaults.AuthenticationScheme,
                                In = Microsoft.OpenApi.Models.ParameterLocation.Header,
                                Reference= new Microsoft.OpenApi.Models.OpenApiReference()
                                {
                                    Id = JwtBearerDefaults.AuthenticationScheme,
                                    Type = Microsoft.OpenApi.Models.ReferenceType.SecurityScheme
                                }
                            },
                            System.Array.Empty<string>()
                        }
                    });

                    options.AddServer(new Microsoft.OpenApi.Models.OpenApiServer()
                    { Description = "This server", Url = builder.Configuration["server:baseurl"] });
                    options.DocumentFilter<HideNonNapiContentFilter>();
                    options.IncludeXmlComments(Path.ChangeExtension(typeof(NAPIController).Assembly.Location, ".xml"), true);
                }
            );


            builder.Services.AddDataProtection()
                .SetApplicationName("NABUNET")
                .PersistKeysToFileSystem(new System.IO.DirectoryInfo(builder.Configuration["keystoragedirectory"]))
                .ProtectKeysWithCertificate(
                    new System.Security.Cryptography.X509Certificates.X509Certificate2(
                        builder.Configuration["keyprotectioncertificate"],
                        builder.Configuration["keyprotectionpassword"]
                    ));

            builder.Services
                .AddAuthentication(CookieAuthenticationDefaults.AuthenticationScheme)
                    .AddJwtBearer(JwtBearerDefaults.AuthenticationScheme, options =>
                    {
                        builder.Configuration.Bind("JwtSettings", options);
                        options.TokenValidationParameters.ValidateIssuerSigningKey = true;
                        options.TokenValidationParameters.ValidIssuer = "NabuNet";
                        options.TokenValidationParameters.ValidAudience = "api";
                        options.TokenValidationParameters.ValidateAudience = true;
                        options.TokenValidationParameters.ValidateIssuer = true;
                        options.TokenValidationParameters.IssuerSigningKey = signer.ValiationKey;
                    })
                    .AddCookie(CookieAuthenticationDefaults.AuthenticationScheme, options =>
                    {
                        options.Cookie.Name = "auth";
                        options.Cookie.SameSite = Microsoft.AspNetCore.Http.SameSiteMode.Strict;
                        options.Cookie.SecurePolicy = Microsoft.AspNetCore.Http.CookieSecurePolicy.Always;
                        options.Cookie.HttpOnly = true;
                        builder.Configuration.Bind("CookieSettings", options);
                        options.LoginPath = "/login";
                    });

            builder.Services.AddAuthorization(x =>
            {
                x.AddPolicy(SecurityPolicy.User, p => p.RequireClaim(SecurityTypes.UserTypeClaim, SecurityTypes.UserTypeUser).AddAuthenticationSchemes(JwtBearerDefaults.AuthenticationScheme, CookieAuthenticationDefaults.AuthenticationScheme));
                x.AddPolicy(SecurityPolicy.Any, p => p.RequireAuthenticatedUser().AddAuthenticationSchemes(JwtBearerDefaults.AuthenticationScheme, CookieAuthenticationDefaults.AuthenticationScheme));
                x.AddPolicy(SecurityPolicy.SiteAdmin, p => p.RequireRole(SecurityTypes.RoleAdministrator).AddAuthenticationSchemes(JwtBearerDefaults.AuthenticationScheme, CookieAuthenticationDefaults.AuthenticationScheme));
                x.AddPolicy(SecurityPolicy.UserAdmin, p => p.RequireRole(SecurityTypes.RoleUserAdmin).AddAuthenticationSchemes(JwtBearerDefaults.AuthenticationScheme, CookieAuthenticationDefaults.AuthenticationScheme));
                x.AddPolicy(SecurityPolicy.Moderator, p => p.RequireRole(SecurityTypes.RoleModerator).AddAuthenticationSchemes(JwtBearerDefaults.AuthenticationScheme, CookieAuthenticationDefaults.AuthenticationScheme));
                x.AddPolicy(SecurityPolicy.ContentManager, p => p.RequireRole(SecurityTypes.RoleContentManager).AddAuthenticationSchemes(JwtBearerDefaults.AuthenticationScheme, CookieAuthenticationDefaults.AuthenticationScheme));
            });

            builder.Services.AddOptions()
                .Configure<ServerSettings>(builder.Configuration.GetSection("server"))
                .Configure<MailConfig>(builder.Configuration.GetSection("mail"))
                .Configure<StorageConfig>(builder.Configuration.GetSection("storage"))
                .Configure<LoginSettings>(builder.Configuration.GetSection("login"));

            builder.Services.AddCaptcha(options =>
                        {
                            // options.UseSessionStorageProvider() // -> It doesn't rely on the server or client's times. Also it's the safest one.
                            // options.UseMemoryCacheStorageProvider() // -> It relies on the server's times. It's safer than the CookieStorageProvider.
                            options.UseCookieStorageProvider(Microsoft.AspNetCore.Http.SameSiteMode.Strict /* If you are using CORS, set it to `None` */) // -> It relies on the server and client's times. It's ideal for scalability, because it doesn't save anything in the server's memory.
                                                                                                                                                          // .UseDistributedCacheStorageProvider() // --> It's ideal for scalability using `services.AddStackExchangeRedisCache()` for instance.
                                                                                                                                                          // .UseDistributedSerializationProvider()

                            // Don't set this line (remove it) to use the installed system's fonts (FontName = "Tahoma").
                            // Or if you want to use a custom font, make sure that font is present in the wwwroot/fonts folder and also use a good and complete font!
                            .UseCustomFont(Path.Combine(System.Environment.CurrentDirectory, "theming", "captcha.ttf"))
                            .AbsoluteExpiration(minutes: 7)
                            .ShowThousandsSeparators(false)
                            .WithNoise(pixelsDensity: 25, linesCount: 3)
                            .WithEncryptionKey("This is my secure key!")
                            .InputNames(// This is optional. Change it if you don't like the default names.
                                new CaptchaComponent
                                {
                                    CaptchaHiddenInputName = "DNT_CaptchaText",
                                    CaptchaHiddenTokenName = "DNT_CaptchaToken",
                                    CaptchaInputName = "DNT_CaptchaInputText"
                                })
                            .Identifier("dnt_Captcha")// This is optional. Change it if you don't like its default name.
                            ;
                        });

            builder.Services
                .AddHttpClient()
                .AddSingleton<ServerConfig>()
                .AddTransient<IServerConfigFactory, ServerConfigFactory>()
                .AddSingleton<IDatabase, FileBasedDatabase>()
                .AddSingleton<IUserManager, UserManager>()
                .AddTransient<IPasswordQualityChecker, PwndPasswordsLookup>()
                .AddTransient<IPasswordQualityChecker, PasswordLengthChecker>()
                .AddTransient<PasswordChecker>()
                .AddTransient<IMailSender, MailSender>()
                .AddTransient<IVirtualServerManager, VirtualServerManager>()
                .AddTransient<ICache, MomoryCacheImplementation>()
                .AddSingleton<IAssetManager, AssetManager>()
                .AddSingleton<ILibraryCredits>(new LibraryCreditFileReader("library-credits.json", "Libraries"))
                .AddSingleton<ILibraryCredits>(new LibraryCreditFileReader("assets-credits.json", "Assets"))
                .AddSingleton<ILibraryCredits>(new LibraryCreditFileReader("theming/credits.json", "Theme specific"))
                .AddTransient<IAdminReportManager, AdminReportManager>()
                .AddTransient<ITemplateManager, FileTemplateManager>()
                .Configure<ForwardedHeadersOptions>(options =>
                    {
                        options.ForwardedHeaders = Microsoft.AspNetCore.HttpOverrides.ForwardedHeaders.All;
                    })
                    ;


            await using (var app = builder.Build())
            {
                // Configure the HTTP request pipeline.
                if (!app.Environment.IsDevelopment())
                {
                    app.UseExceptionHandler("/Home/Error");
                    // The default HSTS value is 30 days. You may want to change this for production scenarios, see https://aka.ms/aspnetcore-hsts.
                    app.UseHsts();
                }
                else
                {
                    app.UseSwagger();
                    app.UseSwaggerUI();
                }

                app.UseForwardedHeaders();

                app.UseHttpsRedirection();
                app.UseWebSockets(new WebSocketOptions() { KeepAliveInterval = System.TimeSpan.FromMinutes(1) });
                app.Map("/api", x => x.UseMiddleware<NabuModemMiddleware>());

                app.UseMiddleware<ThemingRedirector>();
                app.UseStaticFiles();

                app.UseRouting();

                app.UseAuthorization();
                app.UseAuthentication();

                app.MapControllerRoute(
                    name: "default",
                    pattern: "{controller=Home}/{action=Index}/{id?}");

                app.MapControllers();

                app.Run();
            }
        }
    }
}