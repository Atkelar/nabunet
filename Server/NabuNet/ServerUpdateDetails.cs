using System;

namespace NabuNet
{
    public class ServerUpdateDetails
    {
        public string? ConfigImageVersion { get;set;}
        public string? FirmwareImageVersion { get;set;}

        public int? ConfigImageAsset { get;set;}
        public int? FirmwareImageAsset { get;set;}
    }
}