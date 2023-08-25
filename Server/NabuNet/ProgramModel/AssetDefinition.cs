using System;

namespace NabuNet.ProgramModel
{
    public class AssetDefinition
    {
        public int Id { get; set; }
        public string Name { get; set; }
        public int Version { get; set; }


        public AssetType Type { get; set; }
        public AssetBlobInfo[] Blobs { get; set; }
        public DateTime CreatedAt { get; set; }
        public bool Visible { get; set; }
        public string VersionLabel { get; set; }
        public string Author { get; set; }
        /// <summary>
        /// The required kernel to run this asset; 0 = "any". If the asset is itself a Kernel, this instead declares the type.
        /// </summary>
        public int KernelType { get; set; }
    }
}