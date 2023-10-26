using System;

namespace NabuNet.ModemPacktes
{
    public class UpdateImageResponse
        : BasePacket
    {
        public UpdateImageResponse(string? configImageVersion, string? firmwareImageVersion)
            : base(7)
        {
            FirmwareVersion = firmwareImageVersion;
            ConfigVersion = configImageVersion;
        }

        public string FirmwareVersion { get; set; }
        public string ConfigVersion { get; set; }

        protected override void DeserializeNow(ArraySegment<byte> data)
        {
            throw new NotImplementedException();
        }
        protected override int SerializeNow(ArraySegment<byte> data)
        {
            data[0] = (byte)((!string.IsNullOrEmpty(ConfigVersion) ? 1 : 0) | (!string.IsNullOrEmpty(FirmwareVersion) ? 2 : 0));
            int ofs = 1;
            if ((data[0] | 1)!=0) ofs= PutString(data, ofs, ConfigVersion);
            if ((data[0] | 2)!=0) ofs = PutString(data, ofs, FirmwareVersion);
            return ofs;
        }
    }
}