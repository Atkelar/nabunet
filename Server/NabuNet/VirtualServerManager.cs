using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.Extensions.Options;

namespace NabuNet
{

    public class VirtualServerManager
        : IVirtualServerManager
    {
        private readonly IDatabase _Database;

        private readonly StorageConfig _StorageConfig;
        private string _ServerRootFolder;
        private readonly ICache _Cache;
        private readonly IAssetManager _Assets;

        public VirtualServerManager(IDatabase database, IOptions<StorageConfig> storage, ICache cache, IAssetManager assets)
        {
            _Database = database;
            _StorageConfig = storage.Value;
            _ServerRootFolder = Path.Combine(_StorageConfig.BaseFolder, _StorageConfig.VServerFolder);
            _Cache = cache;
            _Assets = assets;
        }

        private const string ServerDocumentName = "server";

        public async Task<IEnumerable<VirtualServerInfo>> GetList()
        {
            List<VirtualServerInfo> result = new List<VirtualServerInfo>();
            foreach (var item in await _Database.GetDocumentListAsync(ServerDocumentName))
            {
                result.Add(await _Cache.GetCachedVersion(ServerDocumentName, item, async x => await _Database.GetDocumentAsync<VirtualServerInfo>(ServerDocumentName, x)));
            }
            if (!result.Any(x => x.Code == 0))
            {
                VirtualServerInfo info = await EnsureRootServer();
                result.Insert(0, info);
            }
            return result.OrderBy(x => x.Code);
        }



        private async Task<VirtualServerInfo> EnsureRootServer()
        {

            // MUST include a "0" server;
            VirtualServerInfo info = new VirtualServerInfo()
            {
                Code = 0,
                Name = "Root",
                Owner = "#System",
                IsActive = true
            };
            await _Database.SetDocumentAsync(ServerDocumentName, info);
            await _Cache.UpdateCachedVersion(ServerDocumentName, info.Id, info);
            return info;
        }

        private class ServerDetailsSerialized
        {
            public ModemMode ModemMode { get; set; }
            public int KernelAsset { get; set; }
            public int LoaderAsset { get; set; }
        }

        public async Task<VirtualServerDetails?> GetDetails(int code, bool onylEnabled)
        {
            VirtualServerInfo? info = await GetInfoByCode(code);
            if (info == null || onylEnabled && !info.IsActive)
                return null;

            var details = await GetInternalDetails(code);
            return new VirtualServerDetails()
            {
                IsNabuNet = details.ModemMode == ModemMode.NabuNet,
                Kernel = details.KernelAsset,
                Loader = details.LoaderAsset,
                Info = info
            };
        }

        private const string ServerDetailsType = "vsdet";

        private async Task<ServerDetailsSerialized?> GetInternalDetails(int code)
        {
            return await _Cache.GetCachedVersion<ServerDetailsSerialized?>(ServerDetailsType, code.ToString("X4"), LoadServerDetails);
        }

        private async Task<ServerDetailsSerialized?> LoadServerDetails(string code)
        {
            int id = int.Parse(code, System.Globalization.NumberStyles.HexNumber);
            string folder = EnsureServerPath(id);
            string file = Path.Combine(folder, "$meta.json");
            if (!File.Exists(file))
            {
                ServerDetailsSerialized newItem = new ServerDetailsSerialized();
                newItem.KernelAsset = 0;
                newItem.LoaderAsset = 0;
                newItem.ModemMode = ModemMode.NabuNet;
                await File.WriteAllTextAsync(file, System.Text.Json.JsonSerializer.Serialize<ServerDetailsSerialized>(newItem));
                return newItem;
            }
            else
            {
                return System.Text.Json.JsonSerializer.Deserialize<ServerDetailsSerialized>(await File.ReadAllTextAsync(file));
            }
        }

        private string EnsureServerPath(int code)
        {
            string path = GetServerPath(code);
            if (!Directory.Exists(path))
                Directory.CreateDirectory(path);
            return path;
        }

        private string GetServerPath(int code)
        {
            return Path.Combine(_ServerRootFolder, code.ToString("X4"));
        }

        private async Task<VirtualServerInfo?> GetInfoByCode(string code)
        {
            return await _Cache.GetCachedVersion(ServerDocumentName, code, async x => await _Database.GetDocumentAsync<VirtualServerInfo>(ServerDocumentName, x));
        }
        private Task<VirtualServerInfo?> GetInfoByCode(int code)
        {
            return GetInfoByCode(code.ToString("X4"));
        }

        public async Task UpdateOwner(int id, string newOwner)
        {
            var idString = id.ToString("X4");
            var doc = await _Database.GetDocumentAsync<VirtualServerInfo>(ServerDocumentName, idString);
            if (newOwner != doc.Owner)
            {
                doc.Owner = newOwner;
                await _Database.SetDocumentAsync(ServerDocumentName, doc);
                await _Cache.UpdateCachedVersion(ServerDocumentName, idString, doc);
            }
        }

        public async Task UpdateName(int id, string newName)
        {
            var idString = id.ToString("X4");
            var doc = await _Database.GetDocumentAsync<VirtualServerInfo>(ServerDocumentName, idString);
            if (newName != doc.Name)
            {
                doc.Name = newName;
                await _Database.SetDocumentAsync(ServerDocumentName, doc);
                await _Cache.UpdateCachedVersion(ServerDocumentName, idString, doc);
            }
        }

        public async Task SetEnabled(int id, bool value)
        {
            var idString = id.ToString("X4");
            var doc = await _Database.GetDocumentAsync<VirtualServerInfo>(ServerDocumentName, idString);
            if (value != doc.IsActive)
            {
                doc.IsActive = value;
                await _Database.SetDocumentAsync(ServerDocumentName, doc);
                await _Cache.UpdateCachedVersion(ServerDocumentName, idString, doc);
            }
        }

        public async Task SetKernelAsset(int id, int value)
        {
            var details = await GetInternalDetails(id);

            var def = await _Assets.GetInfo(value);
            if (def.Type != ProgramModel.AssetType.Kernel)
                throw new InvalidOperationException("Asset is not a kernel image!");

            if (details.KernelAsset != 0)
            {
                var old = await _Assets.GetInfo(details.KernelAsset);
                if (old.KernelType != def.KernelType)
                    details.LoaderAsset = 0;
            }
            details.KernelAsset = value;

            await UpdateInternalDetails(id, details);
        }

        private async Task UpdateInternalDetails(int id, ServerDetailsSerialized details)
        {
            string folder = EnsureServerPath(id);
            string file = Path.Combine(folder, "$meta.json");
            await File.WriteAllTextAsync(file, System.Text.Json.JsonSerializer.Serialize<ServerDetailsSerialized>(details));
            await _Cache.UpdateCachedVersion<ServerDetailsSerialized?>(ServerDetailsType, id.ToString("X4"), details);
        }

        public async Task SetLoaderAsset(int id, int value)
        {
            var details = await GetInternalDetails(id);

            var def = await _Assets.GetInfo(value);
            if (def.Type != ProgramModel.AssetType.Program)
                throw new InvalidOperationException("Asset is not a program image!");

            if (details.KernelAsset == 0)
            {
                throw new InvalidOperationException("Cannot assign a loader without a kernel!");
            }
            var kernel = await _Assets.GetInfo(details.KernelAsset);
            if (kernel.KernelType != def.KernelType)
                throw new InvalidOperationException("The loader and kernel type don't match!");
            details.LoaderAsset = value;

            await UpdateInternalDetails(id, details);
        }
    }
}