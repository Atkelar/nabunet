using System;
using System.Net.WebSockets;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using NabuNet.ModemPacktes;

namespace NabuNet.ModemHandlers
{
    public class ModemSession
    {
        private readonly WebSocket Socket;
        private readonly IServiceProvider Services;
        private readonly ILogger Logger;

        public ModemSession(WebSocket webSocket, IServiceProvider services)
        {
            Socket = webSocket;
            Services = services;
            Logger = services.GetRequiredService<ILogger<ModemSession>>();
        }

        public bool Established { get; set; }

        private string? RemoteModemVersion;
        private byte RequestedApiVersion;
        private string? RemoteConfigVersion;
        private string? RemoteMacAddress;

        byte[] inputBuffer = new byte[512];

        ArraySegment<byte> output = new ArraySegment<byte>(new byte[512]);


        internal async Task RunAsync(CancellationToken token)
        {
            ArraySegment<byte> input = new ArraySegment<byte>(inputBuffer);
            try
            {
                while (true)
                {
                    if (Socket.State != WebSocketState.Open)
                    {
                        Logger.LogWarning("Exiting modem loop for status: {status}", Socket.State);
                        break;
                    }
                    var result = await Socket.ReceiveAsync(input, token);
                    if (result.MessageType != WebSocketMessageType.Binary)
                    {
                        if (result.CloseStatus.HasValue)
                        {
                            Logger.LogInformation("Remote session closed: {closetype}", result.CloseStatus);
                            break;
                        }
                        if (result.Count == 4 && System.Text.Encoding.UTF8.GetString(input.AsSpan(0, 4)) == "ping")
                        {
                            await Socket.SendAsync(System.Text.Encoding.UTF8.GetBytes("pong!"), WebSocketMessageType.Text, true, token);
                        }
                        else
                            throw new InvalidOperationException($"NabuNet protocol is binary! Received {result.Count} bytes as text...");
                    }
                    if (result.Count > 0)
                    {
                        var trimmed = input.Slice(0, result.Count);
                        if (Established)
                        {
                            switch (trimmed[0])
                            {
                                case 2: // request validate channel code...
                                    var request = BasePacket.Deserialize<ValidateChannelCodeRequest>(trimmed);
                                    var servers = Services.GetRequiredService<IVirtualServerManager>();
                                    var info = await servers.GetDetails(request.Code, false);
                                    if (info == null)
                                    {
                                        Logger.LogInformation("Info: {code} is not enabled or doesn't exist.", request.Code);
                                        await SendReply(new ValidateChannelCodeResponse() { IsValid = false }, token);
                                    }
                                    else
                                    {
                                        Logger.LogInformation("Info: {code} found: {name}", request.Code, info.Info.Name);
                                        await SendReply(new ValidateChannelCodeResponse() { IsValid = true, IsNabuNet = info.IsNabuNet, KernelAsset = info.Kernel, LoaderAsset = info.Loader }, token);
                                    }
                                    break;
                                case 4:
                                    var requestBoot = BasePacket.Deserialize<LoadBootBlockRequest>(trimmed);
                                    LoadBootBlockResponse response = new LoadBootBlockResponse();
                                    var info2 = await Services.GetRequiredService<IVirtualServerManager>().GetDetails(requestBoot.Channel, false);
                                    if (info2 != null)
                                    {
                                        if (info2.Kernel != requestBoot.AssetId)
                                            Logger.LogWarning("Requested boot asset {rq} is not the current kernel asset {cur}", requestBoot.AssetId, info2.Kernel);
                                        var assets = Services.GetRequiredService<IAssetManager>();
                                        var assetInfo = await assets.GetInfo(requestBoot.AssetId);
                                        if (assetInfo != null && assetInfo.Type == ProgramModel.AssetType.Kernel)
                                        {
                                            int offset = requestBoot.Block * requestBoot.BlockSize;
                                            var blockResult = await assets.GetBlockFromFile(requestBoot.AssetId, "code.bin", offset, requestBoot.BlockSize);
                                            response.IsLastBlock = (offset + blockResult.Result.Length >= blockResult.filesize);
                                            response.Data = blockResult.Result;
                                        }
                                    }
                                    await SendReply(response, token);
                                    break;
                            }
                        }
                        else
                        {
                            switch (trimmed[0])
                            {
                                case 0: // request for server status/connect...
                                    if (Established = ValidateConnectionRequest(BasePacket.Deserialize<ModemConnectRequest>(trimmed)))
                                    {
                                        Logger.LogInformation("Client connected from {Mac}: Firmware {Modem} / Config {Config} - RqAPI: {Api}", RemoteMacAddress, RemoteModemVersion, RemoteConfigVersion, RequestedApiVersion);
                                        await SendReply(await MakeServerReply(), token);
                                    }
                                    break;
                            }
                        }
                    }
                }
            }
            catch (System.Net.WebSockets.WebSocketException ex)
            {
                Logger.LogError(ex, "Exiting modem loop for WebSocket connection error");
            }
            catch (Exception ex)
            {
                Logger.LogError(ex, "Exiting modem loop for unhandled error!");
                if (Socket.State == WebSocketState.Open)
                    await Socket.CloseAsync(WebSocketCloseStatus.InternalServerError, "Server error.", token);
            }
            finally
            {
                if (Socket.State == WebSocketState.Open)
                    await Socket.CloseAsync(WebSocketCloseStatus.NormalClosure, "Handler closed.", token);
            }
        }

        private async Task<ModemConnectResponse> MakeServerReply()
        {
            var cfg = await Services.GetRequiredService<IServerConfigFactory>().GetOrLoad();
            return new ModemConnectResponse()
            {
                AllowLogin = cfg.EnableLogin,
                GuestAccess = cfg.EnableGustAccess,
                HasVirtualServers = cfg.EnableVirtualServers,
                IsReadOnly = true,
                ServerApiVersion = RequestedApiVersion,
                ServerVersion = $"{this.GetType().Assembly.GetName().Name} {this.GetType().Assembly.GetName().Version} ({MaximumApiVersionSupported})",
                ServerName = cfg.ServerName
            };
        }

        private async Task SendReply(BasePacket reply, CancellationToken token)
        {
            int len = reply.Serialize(output);
            await Socket.SendAsync(output.Slice(0, len), WebSocketMessageType.Binary, true, token);
        }

        private const byte MinimumApiVersionSupported = 1;
        private const byte MaximumApiVersionSupported = NAPIController.ApiVersionLevel;


        private bool ValidateConnectionRequest(ModemConnectRequest request)
        {
            if (request.RequestedApiVersion >= MinimumApiVersionSupported && request.RequestedApiVersion <= MaximumApiVersionSupported)
            {
                RemoteMacAddress = request.MacAddress;
                RemoteConfigVersion = request.ModemConfigVersion;
                RemoteModemVersion = request.ModemVersion;
                RequestedApiVersion = request.RequestedApiVersion;
                return true;
            }
            else
            {
                Logger.LogWarning("Client request for API version {version} not supported!", request.RequestedApiVersion);
                return false;
            }
        }
    }
}