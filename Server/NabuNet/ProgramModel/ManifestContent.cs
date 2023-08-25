using System.Text.Json.Serialization;

namespace NabuNet.ProgramModel
{
    public class ManifestContent
    {
        [JsonPropertyName("title")]
        public string Title { get; set; }
        [JsonPropertyName("version")]
        public string Version { get; set; }
        [JsonPropertyName("author")]
        public string Author { get; set; }
        [JsonPropertyName("type")]
        public string Type { get; set; }
        [JsonPropertyName("assets")]
        public string[] Assets { get; set; }
        [JsonPropertyName("kerneltype")]
        public string KernelType { get; set; }
    }
}