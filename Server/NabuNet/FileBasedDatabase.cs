using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text.Json;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.AspNetCore.DataProtection;
using Microsoft.Extensions.Options;

namespace NabuNet
{
    // A simple, yet versioned "database" consisting of "documents", i.e. JSON serialized information,
    // that is kept in folders. Versioning is done via a version number which is kept in memory
    // for performance reasons. This is why this class MUST be a singleton!
    // NOT SUITABLE for load balanced servers too!
    // TODO: Memory cache for documents with "write-through" logic...
    internal class FileBasedDatabase
        : IDatabase, IAsyncDisposable, IDisposable
    {
        private readonly string _Folder;
        private readonly string _RootFile;
        private readonly string _DocumentsFolder;
        private readonly string _DocumentsRevisionFolder;
        private readonly IDataProtector _Protector;
        private bool _IsInitialized;

        private long _VersionNumber = 0;
        private long _CommittedVersion = 0;
        private DateTime _Created;
        private long? _VersionCache = null;

        public FileBasedDatabase(IOptions<StorageConfig> config, IDataProtectionProvider protectionProvider)
        {
            _Folder = Path.GetFullPath(Path.Combine(config.Value.BaseFolder, config.Value.DatabaseLocation));
            _RootFile = Path.Combine(_Folder, config.Value.DatabaseName + ".db");
            _DocumentsFolder = Path.Combine(_Folder, config.Value.DatabaseName);
            _DocumentsRevisionFolder = Path.Combine(_Folder, config.Value.DatabaseName + ".rev");

            _Protector = protectionProvider.CreateProtector("database");
        }

        private class DatabaseMetadata
        {
            public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
            public long CommittedVersion { get; set; } = 0;
            public long? VersionCache { get; set; } = null;
        }

        private async Task Initialize()
        {
            if (!Directory.Exists(_Folder))
                Directory.CreateDirectory(_Folder);
            if (!Directory.Exists(_DocumentsFolder))
                Directory.CreateDirectory(_DocumentsFolder);
            if (!Directory.Exists(_DocumentsRevisionFolder))
                Directory.CreateDirectory(_DocumentsRevisionFolder);

            DatabaseMetadata meta;
            bool needsRepair = false;

            if (File.Exists(_RootFile))
            {
                meta = JsonSerializer.Deserialize<DatabaseMetadata>(await File.ReadAllTextAsync(_RootFile)) ?? new DatabaseMetadata();
                needsRepair = meta.VersionCache.HasValue;   // we didn't close "clean"... uh-oh...
            }
            else
            {
                meta = new DatabaseMetadata();
                await File.WriteAllTextAsync(_RootFile, JsonSerializer.Serialize<DatabaseMetadata>(meta));  // create the file.
            }

            _CommittedVersion = _VersionNumber = meta.CommittedVersion;
            _Created = meta.CreatedAt;

            await File.AppendAllTextAsync(_RootFile + ".openlog", $"{DateTime.UtcNow:yyyy-MM-ddZHH:mm:ss.fff} open, version = {_VersionNumber}{Environment.NewLine}");
            if (needsRepair)
            {
                await File.AppendAllTextAsync(_RootFile + ".openlog", $" Repair, unclean shutdown...{Environment.NewLine}");

                _CommittedVersion = _VersionNumber = (await FindLatestVersionInRevisions(_CommittedVersion));   // "next" version will be incremented, so latest tag = current version

                await File.AppendAllTextAsync(_RootFile + ".openlog", $" ...repair found {_VersionNumber} as newest.{Environment.NewLine}");
            }

            _VersionCache = _VersionNumber + 1000;

            await FlushAsync();

            _IsInitialized = true;
        }

        private async Task<long> FindLatestVersionInRevisions(long committedVersion)
        {
            // repair code; the last shutdown was "dirty", so we need to find the latest revision number in the "rev" directory, which might take a bit...

            // folder structure:
            //  REV-DIR/tablename/version.json
            //  REV-DIR/tablename~/id/version.json

            foreach (var tablefolder in Directory.GetDirectories(_DocumentsRevisionFolder))
            {
                long l = await FindLatestVersionInRevisions(tablefolder, committedVersion);
                if (l > committedVersion)
                    committedVersion = l;
            }

            return committedVersion;
        }

        private async Task<long> FindLatestVersionInRevisions(string tablefolder, long committedVersion)
        {
            if (tablefolder.EndsWith("~"))
            {
                // we have subfolders for the "records".
                foreach (var recordFolder in Directory.GetDirectories(tablefolder))
                {
                    var l = await (FindLatestVersionInRevisions(recordFolder, committedVersion));
                    if (l > committedVersion)
                        committedVersion = l;
                }
            }
            else
            {
                // we are here.
                var di = new DirectoryInfo(tablefolder);
                var files = di.GetFiles("????????.json");
                var last = files.OrderBy(x => x.Name).LastOrDefault();
                if (last != null)
                {
                    long l = long.Parse(last.Name.AsSpan(0, 8), System.Globalization.NumberStyles.HexNumber);
                    if (l > committedVersion)
                        return l;
                }
            }
            return committedVersion;
        }

        // Gets called in every other method.
        // Is kept brief to allow inlining!
        private Task EnsureInitialized()
        {
            if (_IsInitialized)
                return Task.CompletedTask;
            return Initialize();
        }

        public async Task<T?> GetSingleDocumentAsync<T>(string documentName) where T : class
        {
            await EnsureInitialized();
            var name = Path.Combine(_DocumentsFolder, $"{documentName}.json");
            if (!File.Exists(name))
                return null;
            return JsonSerializer.Deserialize<T>(await File.ReadAllTextAsync(name));
        }

        public async Task<T> GetSingleRequiredDocumentAsync<T>(string documentName) where T : class, new()
        {
            return await GetSingleDocumentAsync<T>(documentName) ?? new T();
        }

        // take next version number for TX - updating the cache counter if required.
        private async Task<long> GetVersionForCurrentChange()
        {
            if (!_VersionCache.HasValue || _VersionNumber >= _VersionCache.Value)
            {
                bool wasDoneHere = false;
                lock (this)  // singleton, make sure we are not caching double...
                {
                    if (!_VersionCache.HasValue || _VersionNumber >= _VersionCache.Value)
                    {
                        _VersionCache = _VersionNumber + 1000;
                        wasDoneHere = true;
                    }
                }
                if (wasDoneHere)
                    await FlushAsync(true);
            }
            return Interlocked.Increment(ref _VersionNumber);
        }

        public async Task SetSingleDocumentAsync<T>(string documentName, T content) where T : class
        {
            await EnsureInitialized();
            var thisVersion = await GetVersionForCurrentChange();
            string newName = await MoveHistoryVersionSingleFileAsync(documentName, thisVersion);
            await File.AppendAllTextAsync(newName, JsonSerializer.Serialize(content));
        }

        private async Task<string> MoveHistoryVersionSingleFileAsync(string documentName, long thisVersion)
        {
            var newName = Path.Combine(_DocumentsFolder, $"{documentName}.json");
            if (File.Exists(newName))
            {
                var targetPath = Path.Combine(_DocumentsRevisionFolder, documentName);
                if (!Directory.Exists(targetPath))
                    Directory.CreateDirectory(targetPath);
                targetPath = Path.Combine(targetPath, $"{thisVersion:x8}.json");
                File.Move(newName, targetPath);
            }
            return newName;
        }

        private static readonly System.Text.RegularExpressions.Regex KeyValidator = new System.Text.RegularExpressions.Regex("^[0-9a-zA-Z_-]+$");

        private async Task<string> MoveHistoryVersionFileAsync(string documentName, string validatedKey, long thisVersion)
        {
            var newName = Path.Combine(_DocumentsFolder, $"{documentName}-{validatedKey}.json");
            if (File.Exists(newName))
            {
                var targetPath = Path.Combine(_DocumentsRevisionFolder, documentName + "~", validatedKey);
                if (!Directory.Exists(targetPath))
                    Directory.CreateDirectory(targetPath);
                targetPath = Path.Combine(targetPath, $"{thisVersion:x8}.json");
                File.Move(newName, targetPath);
            }
            return newName;
        }

        private static string ValidateKey(string key)
        {
            if (!KeyValidator.IsMatch(key))
                throw new InvalidOperationException("Database key invalid! Might contain dangerous characters: " + key);
            return key.ToLowerInvariant();
        }

        public async ValueTask DisposeAsync()
        {
            if (_VersionNumber != _CommittedVersion)
                await FlushAsync(false);
            await File.AppendAllTextAsync(_RootFile + ".openlog", $"{DateTime.UtcNow:yyyy-MM-ddZHH:mm:ss.fff} close, version = {_VersionNumber}{Environment.NewLine}");
        }

        public Task FlushAsync()
        {
            return FlushAsync(true);
        }
        public async Task FlushAsync(bool includeCachedVersion)
        {
            var meta = new DatabaseMetadata() { CommittedVersion = _VersionNumber, CreatedAt = _Created, VersionCache = includeCachedVersion ? _VersionCache : null };
            await File.WriteAllTextAsync(_RootFile, JsonSerializer.Serialize<DatabaseMetadata>(meta));  // create the file.
            _CommittedVersion = _VersionNumber;
        }

        public void Dispose()
        {
            DisposeAsync().AsTask().Wait();
        }

        public async Task RemoveSingleDocumentAsync(string documentName)
        {
            await EnsureInitialized();
            var thisVersion = Interlocked.Increment(ref _VersionNumber);
            var newName = await MoveHistoryVersionSingleFileAsync(documentName, thisVersion);
            // no new file; "remvoe" means: delete.
        }

        public async Task<T?> GetDocumentAsync<T>(string documentName, string key) where T : class, IKeyRecord
        {
            await EnsureInitialized();
            key = ValidateKey(key);

            var newName = Path.Combine(_DocumentsFolder, $"{documentName}-{key}.json");
            if (!File.Exists(newName))
                return null;
            return JsonSerializer.Deserialize<T>(await File.ReadAllTextAsync(newName));
        }

        public async Task<T> GetRequiredDocumentAsync<T>(string documentName, string key) where T : class, IKeyRecord
        {
            var x = await GetDocumentAsync<T>(documentName, key);
            if (x == null)
                throw new InvalidOperationException($"Document {documentName} with key {key} was not found!");
            return x;
        }

        public async Task SetDocumentAsync<T>(string documentName, T content) where T : class, IKeyRecord
        {
            await EnsureInitialized();
            // check if we update or create...
            var thisVersion = await GetVersionForCurrentChange();

            if (content.Id != null)
            {
                // update...
                string newName = await MoveHistoryVersionFileAsync(documentName, content.Id, thisVersion);
                await File.AppendAllTextAsync(newName, JsonSerializer.Serialize(content));
            }
            else
            {
                // create...
                content.Id = ValidateKey(content.DeriveNewKey());
                string newName = await MoveHistoryVersionFileAsync(documentName, content.Id, thisVersion);

                await File.AppendAllTextAsync(newName, JsonSerializer.Serialize(content));
            }
        }


        public async Task RemoveDocumentAsync(string documentName, string key)
        {
            await EnsureInitialized();
            throw new NotImplementedException();
        }

        public Task<bool> DocumentExists(string documentName, string key)
        {
            var newName = Path.Combine(_DocumentsFolder, $"{documentName}-{ValidateKey(key)}.json");
            return Task.FromResult(File.Exists(newName));
        }

        public Task<bool> SingleDocumentExists(string documentName)
        {
            var newName = Path.Combine(_DocumentsFolder, $"{documentName}.json");
            return Task.FromResult(File.Exists(newName));
        }

        public Task<IEnumerable<string>> GetDocumentListAsync(string documentName)
        {
            return Task.FromResult(Directory.GetFiles(_DocumentsFolder, $"{documentName}-*.json").Select(x => Path.GetFileNameWithoutExtension(x).Substring(documentName.Length + 1)));
        }
    }
}