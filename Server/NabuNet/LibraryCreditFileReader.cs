using System.Collections.Generic;
using System.Text.Json.Nodes;
using System.Threading.Tasks;

namespace NabuNet
{
    public class LibraryCreditFileReader
        : ILibraryCredits
    {
        private readonly string _Filename;
        private List<LibraryInfo>? _Cache;

        public LibraryCreditFileReader(string filename, string categoryName)
        {
            _Filename = filename;
            Category = categoryName;
        }

        public string Category { get; set; }

        public async Task<IEnumerable<LibraryInfo>> GetLirbaryInfoAsync()
        {
            lock (this)
            {
                if (_Cache != null)
                    return _Cache;
                _Cache = new List<LibraryInfo>();
            }
            if (System.IO.File.Exists(_Filename))
            {
                var info = System.Text.Json.JsonSerializer.Deserialize<Dictionary<string, SerializedInfoHelper>>(await System.IO.File.ReadAllTextAsync(_Filename));
                foreach (var item in info.Values)
                {
                    _Cache.Add(new LibraryInfo() { Name = item.Name, Comment = item.Comment, LicenseUri = item.Url, Version = item.Version });
                }
            }
            return _Cache;
        }



        private class SerializedInfoHelper
        {
            public string Name { get; set; }
            public string? Url { get; set; } = null;
            public string? Version { get; set; } = null;
            public string? Comment { get; set; } = null;
        }
    }
}