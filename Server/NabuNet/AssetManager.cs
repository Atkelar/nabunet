using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Threading.Tasks;
using ICSharpCode.SharpZipLib.Zip;
using Microsoft.Extensions.Options;
using NabuNet.ProgramModel;

namespace NabuNet
{
    public class AssetManager
        : IAssetManager
    {
        public AssetManager(IOptions<StorageConfig> config, IDatabase database)
        {
            _Settings = config.Value;
            _BinaryRootFolder = Path.Combine(_Settings.BaseFolder, _Settings.BinariesLocation);
            if (!Directory.Exists(_BinaryRootFolder))
                Directory.CreateDirectory(_BinaryRootFolder);
            _Database = database;
        }
        public async Task<AssetDefinition> CreateAssetFromBlob(Stream data)
        {
            using (var zipFile = new ZipFile(data, leaveOpen: false))
            {
                if (zipFile.Count > 21)
                    throw new InvalidAssetDefinitionException($"Implausible asset: maximum of 20 files exceeded: {zipFile.Count}");

                // validate contents...
                foreach (ZipEntry item in zipFile)
                {
                    if (!item.CanDecompress)
                        throw new InvalidAssetDefinitionException($"File compression not supported: {item.Name}");
                    if (item.Size > 0x10000)
                        throw new InvalidAssetDefinitionException($"File with size > 64k not supported: {item.Size}");
                }

                var entry = zipFile.FindEntry("manifest.json", false);
                if (entry < 0)
                    throw new InvalidAssetDefinitionException("Packet didn't contain a 'manifest.json' file (case sensitive!)");
                var mfe = zipFile[entry];
                ManifestContent? manifest;
                try
                {
                    using (var manifestFile = zipFile.GetInputStream(mfe))
                    {
                        manifest = System.Text.Json.JsonSerializer.Deserialize<ManifestContent>(manifestFile);
                        // var tr = new System.IO.StreamReader(manifestFile);
                        // _Logger.LogInformation(await tr.ReadToEndAsync());
                    }
                }
                catch (System.Exception ex)
                {
                    throw new InvalidAssetDefinitionException($"Couldn't read the provided manifest file: {ex.Message}");
                }

                if (manifest == null)
                    throw new InvalidAssetDefinitionException($"Manifest file was empty/null?");
                if (manifest.Title == null || !ValidAssetTitleExpression.IsMatch(manifest.Title))
                    throw new InvalidAssetDefinitionException($"Manifest title is invalid. Only alphanumeric and _, - and . are allowed!");
                if (manifest.Version == null || !ValidAssetVersionExpression.IsMatch(manifest.Version))
                    throw new InvalidAssetDefinitionException($"Manifest version is invalid.");

                if (manifest.Assets == null || manifest.Assets.Length == 0)
                    throw new InvalidAssetDefinitionException($"Manifest is missing asset list!");

                for (int i = 0; i < manifest.Assets.Length; i++)
                {
                    if (!ValidAssetFileNameExpression.IsMatch(manifest.Assets[i]))
                        throw new InvalidAssetDefinitionException($"Manifest file name is invalid: {manifest.Assets[i]}");
                    if (zipFile.FindEntry(manifest.Assets[i], false) < 0)
                        throw new InvalidAssetDefinitionException($"Manifest file name is not part of the archive: {manifest.Assets[i]}");
                    for (int j = i + 1; j < manifest.Assets.Length; j++)
                        if (manifest.Assets[i] == manifest.Assets[j])
                            throw new InvalidAssetDefinitionException($"Manifest file name is duplicated: {manifest.Assets[i]}");
                }
                switch (manifest.Type)
                {
                    case "kernel":
                        return await CreateKernelDefinition(zipFile, manifest);
                    default:
                        throw new InvalidAssetDefinitionException($"Manifest type unrecognized: {manifest.Type}");
                }
            }
        }

        private static readonly System.Text.RegularExpressions.Regex ValidAssetFileNameExpression =
            new System.Text.RegularExpressions.Regex(@"^[a-zA-Z0-9_\-]{1,8}(\.[a-zA-Z0-9_\-]{0,3})?$", System.Text.RegularExpressions.RegexOptions.Singleline);

        private static readonly System.Text.RegularExpressions.Regex ValidAssetTitleExpression =
            new System.Text.RegularExpressions.Regex(@"^[a-zA-Z0-9_\-\.][a-zA-Z0-9_\-\.\s]{1,30}[a-zA-Z0-9_\-\.]$", System.Text.RegularExpressions.RegexOptions.Singleline);
        private static readonly System.Text.RegularExpressions.Regex ValidAssetVersionExpression =
            new System.Text.RegularExpressions.Regex(@"^\d{1,3}\.\d{1,3}(\.\d{1,3})?(\-[a-zA-Z]{1,10})?$", System.Text.RegularExpressions.RegexOptions.Singleline);
        private readonly StorageConfig _Settings;
        private readonly string _BinaryRootFolder;
        private readonly IDatabase _Database;

        private async Task<AssetDefinition> CreateKernelDefinition(ZipFile zipFile, ManifestContent manifest)
        {
            if (manifest.Type != "kernel")
                throw new InvalidOperationException("Not a kernel manifest!");

            if (!manifest.Assets.Contains("code.bin"))
                throw new InvalidAssetDefinitionException("Kernel manifest is missing required 'code.bin' file!");
            int? kernelTypeId = await GetKernelTypeFromName(manifest.KernelType);

            if (!kernelTypeId.HasValue)
                throw new InvalidAssetDefinitionException($"Kernel type {manifest.KernelType} not found on this server!");

            AssetDefinition newDef = new AssetDefinition();
            int newAssetId = await ReserveNewIdForAsset("create kernel asset");
            string folderName = await EnsureFolderForAsset(newAssetId);
            List<AssetBlobInfo> blobs = new List<AssetBlobInfo>();
            try
            {
                foreach (var file in manifest.Assets)
                {
                    int size = await ExtractFile(zipFile, file, folderName);
                    blobs.Add(new AssetBlobInfo() { Name = file, Size = size });
                }
            }
            catch (Exception ex)
            {
                throw new InvalidAssetDefinitionException($"Extracting files from package faild: {ex.Message}");
            }

            newDef.Id = newAssetId;
            newDef.Name = $"Kernel {manifest.Title} {manifest.Version}";
            newDef.CreatedAt = DateTime.UtcNow;
            newDef.Visible = true;
            newDef.VersionLabel = manifest.Version;
            newDef.Author = manifest.Author;

            newDef.Type = AssetType.Kernel;
            newDef.KernelType = kernelTypeId.Value;

            newDef.Blobs = blobs.ToArray();

            using (var target = File.Create(Path.Combine(folderName, "$info.json")))
            {
                System.Text.Json.JsonSerializer.Serialize(target, newDef);
            }

            return newDef;
        }

        private async Task<int> ExtractFile(ZipFile zipFile, string file, string folderName)
        {
            int index = zipFile.FindEntry(file, false);
            if (index < 0)  // should NOT happen, just to make a sensible error message anyway.
                throw new InvalidAssetDefinitionException($"File {file} not found in packet?!");
            byte[] buffer = new byte[4096];
            using (var inStream = zipFile.GetInputStream(zipFile[index]))
            {
                using (var outStream = File.Create(Path.Combine(folderName, file)))
                {
                    int r;
                    int len = 0;
                    do
                    {
                        r = await inStream.ReadAsync(buffer, 0, buffer.Length);
                        len += r;
                        if (len > 0x10000)
                        {
                            string error = $"File {file} read more than 64k of input data! Might be a zip-bomb?";
                            await LogStorageActivity(error);
                            throw new InvalidAssetDefinitionException(error);
                        }
                        if (r > 0)
                            outStream.Write(buffer, 0, r);
                    } while (r > 0);
                    return len;
                }
            }
        }

        private string FolderNameForAsset(int assetId)
        {
            int a = (assetId >> 24) & 0xFF;
            int b = (assetId >> 16) & 0xFF;
            int c = (assetId >> 8) & 0xFF;
            int d = assetId & 0xFF;

            return Path.Combine(_BinaryRootFolder, a.ToString("X2"), b.ToString("X2"), c.ToString("X2"), d.ToString("X2"));
        }

        private async Task<string> EnsureFolderForAsset(int newAssetId)
        {
            string folderName = FolderNameForAsset(newAssetId);
            if (!Directory.Exists(folderName))
                Directory.CreateDirectory(folderName);
            return folderName;
        }

        private int? _LastAssignedAssetId = null;

        private async Task<int> ReserveNewIdForAsset(string logMessage)
        {
            if (_LastAssignedAssetId.HasValue)
            {
                int id;
                lock (this)
                {
                    _LastAssignedAssetId++;
                    id = _LastAssignedAssetId.Value;
                }
                await LogStorageActivity($"Reserved id [{id:X8}] for {logMessage}");
                return id;
            }
            else
            {
                int id = await FindLastAssetId();
                lock (this)
                {
                    // this makes sure that even in a race condition, only ONE can assign the latest found ID.
                    // Which should certainly be the correct one, since the code that FIRST hit this path will continue and allocate based on that.
                    if (!_LastAssignedAssetId.HasValue)
                        _LastAssignedAssetId = id;
                }
                return await ReserveNewIdForAsset(logMessage);  // now we have an id, we loop around and use the IF above...
            }
        }

        private async Task<int> FindLastAssetId()
        {
            // folder structure:
            //  0x12345678 -> is decomposed into the folder name 12/34/56/78 - this would limit the number of folders to 256 per subfolder
            // to find the highest used number, we can scan each level, find the highest existing and sub-scan again.
            int a = await FindLatestSubId(_BinaryRootFolder);
            string nextLevel = Path.Combine(_BinaryRootFolder, a.ToString("X2"));
            int b = await FindLatestSubId(nextLevel);
            nextLevel = Path.Combine(nextLevel, b.ToString("X2"));
            int c = await FindLatestSubId(nextLevel);
            nextLevel = Path.Combine(nextLevel, c.ToString("X2"));
            int d = await FindLatestSubId(nextLevel);

            return a << 24 | b << 16 | c << 8 | d;
        }

        private async Task<int> FindLatestSubId(string folderName)
        {
            DirectoryInfo di = new DirectoryInfo(folderName);
            if (!di.Exists)
                return 0;
            var x = di.GetDirectories("??").OrderByDescending(x => x.Name).FirstOrDefault();
            if (x == null)
                return 0;
            return int.Parse(x.Name, System.Globalization.NumberStyles.HexNumber);
        }

        private async Task LogStorageActivity(string message)
        {
            await File.AppendAllLinesAsync(Path.Combine(_BinaryRootFolder, "activity.log"),
                new string[] { $"{System.DateTime.UtcNow:yyyy-MM-dd HH:mm:ss.fff}: {message}" }
            );
        }

        private class KernelTypeSerialized
        {
            public int Id { get; set; }
            public string Name { get; set; }
        }

        List<KernelTypeSerialized>? _KernelTypeList = null;

        private async Task<int?> GetKernelTypeFromName(string kernelType)
        {
            if (_KernelTypeList == null)
            {
                string path = Path.Combine(_BinaryRootFolder, "kernels.json");
                if (File.Exists(path))
                {
                    using (var f = File.OpenRead(path))
                    {
                        _KernelTypeList = System.Text.Json.JsonSerializer.Deserialize<List<KernelTypeSerialized>>(f);
                    }
                }
                else
                {
                    lock (this)
                    {
                        _KernelTypeList = new List<KernelTypeSerialized>();
                        // we bootstrap the "NabuNet" kernel type in as ID #1...
                        _KernelTypeList.Add(new KernelTypeSerialized() { Id = 1, Name = "NabuNet" });
                    }
                    using (var f = File.Create(path))
                    {
                        System.Text.Json.JsonSerializer.Serialize<List<KernelTypeSerialized>>(f, _KernelTypeList);
                    }

                }
            }
            return _KernelTypeList?.FirstOrDefault(x => x.Name.Equals(kernelType, StringComparison.InvariantCultureIgnoreCase))?.Id;
        }

        public async Task<bool> Exists(int assetId)
        {
            return File.Exists(Path.Combine(FolderNameForAsset(assetId), "$info.json"));
        }

        public async Task<AssetDefinition?> GetInfo(int assetId)
        {
            // TODO: caching...
            using (var source = File.OpenRead(Path.Combine(FolderNameForAsset(assetId), "$info.json")))
            {
                return System.Text.Json.JsonSerializer.Deserialize<AssetDefinition>(source);
            }
        }

        public async Task<(byte[]? Result, int filesize)> GetBlockFromFile(int assetId, string filename, int offset, int blockSize)
        {
            filename = Path.Combine(FolderNameForAsset(assetId), filename);
            if (!File.Exists(filename))
                return (null, 0);
            using (var source = File.OpenRead(filename))
            {
                int len = blockSize;
                int filesize = (int)source.Length;
                if (offset + len > filesize)
                    len = filesize - offset;
                byte[] result = new byte[len];
                source.Position = offset;
                if (await source.ReadAsync(result, 0, len) != len)  // with filestreams, this should not happen.
                    return (null, filesize);
                return (result, filesize);
            }
        }
    }
}