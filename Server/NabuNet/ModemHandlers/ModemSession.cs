using System;
using System.Net.WebSockets;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Authentication;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using NabuNet.ModemPacktes;
using NabuNet.ProgramModel;

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

        private int? ConfigImageAsset;
        private int? FirmwareImageAsset;

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
                                    await SendReply(await HandleRequestChannelCodeValidation(BasePacket.Deserialize<ValidateChannelCodeRequest>(trimmed),token), token);
                                    break;
                                case 4: 
                                    await SendReply(await HandleRequestBootBlock(BasePacket.Deserialize<LoadBootBlockRequest>(trimmed), token),token);
                                    break;
                                case 6:
                                    await SendReply(await HandleRequestUpdateImagesVersions(BasePacket.Deserialize<UpdateImageRequest>(trimmed), token),token);
                                    break;
                                case 8:
                                    await SendReply(await HandleRequestDownloadUpdateImage(BasePacket.Deserialize<UpdateImageDownloadRequest>(trimmed), token),token);
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

        private async Task<BasePacket> HandleRequestDownloadUpdateImage(UpdateImageDownloadRequest request, CancellationToken token)
        {
            if (request.Asset == 0)
            {
                // new request... "cookie" not yet known...
                if (!FirmwareImageAsset.HasValue && !ConfigImageAsset.HasValue)
                {
                    var servers = Services.GetRequiredService<IVirtualServerManager>();
                    var details = await servers.GetUpdateDetails();
                    FirmwareImageAsset = details.FirmwareImageAsset;
                    ConfigImageAsset = details.ConfigImageAsset;
                }
                switch(request.Type)
                {
                    case 1:
                        if (ConfigImageAsset.HasValue)
                        {
                            return await MakeUpdateBlockReply(AssetType.Config, ConfigImageAsset.Value, "nabuboot.img", 0, 512, 1, token);
                        }
                        break;
                    case 2:
                        if (FirmwareImageAsset.HasValue)
                        {
                            return await MakeUpdateBlockReply(AssetType.Firmware, FirmwareImageAsset.Value, "nabufirm.img", 0, 512, 2, token);
                        }
                        break;
                }
            }
            else
            {
                switch(request.Type)
                {
                    case 1:
                        return await MakeUpdateBlockReply(null, request.Asset, "nabuboot.img", request.Offset, 512, 1, token);
                    case 2:
                        return await MakeUpdateBlockReply(null, request.Asset, "nabufirm.img", request.Offset, 512, 2, token);
                }
            }
            throw new InvalidOperationException($"Requested asset type {request.Type} isn't avaialble at this server!");
        }

        private async Task<BasePacket> HandleRequestUpdateImagesVersions(UpdateImageRequest request, CancellationToken token)
        {
            var servers = Services.GetRequiredService<IVirtualServerManager>();
            var details = await servers.GetUpdateDetails();

            // remember the image asset IDs for eventual download so they match up to the versions.
            ConfigImageAsset = details.ConfigImageAsset;
            FirmwareImageAsset = details.FirmwareImageAsset;

            return new UpdateImageResponse(details.ConfigImageVersion, details.FirmwareImageVersion);
        }

        private async Task<BasePacket> HandleRequestBootBlock(LoadBootBlockRequest request, CancellationToken token)
        {
            LoadBootBlockResponse response = new LoadBootBlockResponse();
            var info = await Services.GetRequiredService<IVirtualServerManager>().GetDetails(request.Channel, false);
            if (info != null)
            {
                if (info.Kernel != request.AssetId)
                    Logger.LogWarning("Requested boot asset {rq} is not the current kernel asset {cur}", request.AssetId, info.Kernel);
                var assets = Services.GetRequiredService<IAssetManager>();
                var assetInfo = await assets.GetInfo(request.AssetId);
                if (assetInfo != null && assetInfo.Type == ProgramModel.AssetType.Kernel)
                {
                    int offset = request.Block * request.BlockSize;
                    var blockResult = await assets.GetBlockFromFile(request.AssetId, "code.bin", offset, request.BlockSize);
                    if (blockResult.Result == null)
                        throw new InvalidOperationException("Block read outside bounds!");
                    response.IsLastBlock = offset + blockResult.Result.Length >= blockResult.FileSize;
                    response.Data = blockResult.Result;
                }
            }
            return response;
        }

        private async Task<BasePacket> HandleRequestChannelCodeValidation(ValidateChannelCodeRequest request, CancellationToken token)
        {
            var servers = Services.GetRequiredService<IVirtualServerManager>();
            var info = await servers.GetDetails(request.Code, false);
            if (info == null)
            {
                Logger.LogInformation("Info: {code} is not enabled or doesn't exist.", request.Code);
                return new ValidateChannelCodeResponse() { IsValid = false };
            }
            else
            {
                Logger.LogInformation("Info: {code} found: {name}", request.Code, info.Info.Name);
                return new ValidateChannelCodeResponse() { IsValid = true, IsNabuNet = info.IsNabuNet, KernelAsset = info.Kernel, LoaderAsset = info.Loader };
            }
        }

        private async Task<BasePacket> MakeUpdateBlockReply(AssetType? expectedType, int assetId, string filename, int offset, int blockSize, byte type, CancellationToken token)
        {
            var assets = Services.GetRequiredService<IAssetManager>();
            if (expectedType.HasValue)
            {
                var info = await assets.GetInfo(assetId);
                if (info.Type != expectedType)
                    throw new InvalidOperationException("Asset isn't the correct type of image!");
            }
            //Task<(byte[]? Result, int filesize)> GetBlockFromFile(int assetId, string filename, int offset, int blockSize);
            var result = await assets.GetBlockFromFile(assetId, filename, offset, blockSize);
            if (result.Result == null)
                throw new InvalidOperationException("Asset read out of bounds!");
            return new UpdateImageDownloadResponse(type, assetId, result.FileSize, result.Result);
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