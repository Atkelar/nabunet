using System.Threading.Tasks;
using Microsoft.AspNetCore.Http;

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
            }
        }
    }
}