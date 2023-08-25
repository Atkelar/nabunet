using System.Collections.Generic;

namespace NabuNet
{
    public class LibraryInfo
    {
        public string Name { get; set; }
        public string? LicenseUri { get; set; }
        public string? Comment { get; set; }
        public string? Version { get; internal set; }
    }
}