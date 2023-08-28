using System;
using System.Text;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;

namespace NabuNet
{
    public class NabuModemMiddleware
    {
        private readonly RequestDelegate _next;

        public NabuModemMiddleware(RequestDelegate next)
        {
            _next = next;
        }

        public async Task InvokeAsync(HttpContext context)
        {
            if (context.WebSockets.IsWebSocketRequest)
            {
                using var webSocket = await context.WebSockets.AcceptWebSocketAsync();
                var session = new NabuNet.ModemHandlers.ModemSession(webSocket, context.RequestServices);
                var token = (new System.Threading.CancellationTokenSource()).Token;
                await session.RunAsync(token);   // we NEED to keep awaiting until the client disconnects...
            }
            else
            {
                context.Response.StatusCode = StatusCodes.Status400BadRequest;
                ILogger<NabuModemMiddleware> logger = context.RequestServices.GetRequiredService<ILogger<NabuModemMiddleware>>();
                if (logger.IsEnabled(LogLevel.Trace))
                {
                    StringBuilder sb = new StringBuilder();
                    sb.AppendLine("Non-WS request received:");
                    foreach (var item in context.Request.Headers)
                    {
                        sb.AppendFormat("  {0}: {1}{2}", item.Key, item.Value, Environment.NewLine);
                    }
                    logger.LogTrace(sb.ToString());
                }
            }
        }
    }
}