using System;

namespace NabuNet.ModemPacktes
{
    public class UpdateImageDownloadResponse
        : BasePacket
    {
        public UpdateImageDownloadResponse(byte assetType, int assetId, int size, byte[] buffer, int? checksum = null)
            : base(9)
        {
            Type = assetType;
            AssetId = assetId;
            CheckSum = checksum;
            Buffer = buffer;
            Size = size;
        }

        public UpdateImageDownloadResponse()
            : base(9)
        {
            AssetId = 0;
        }

        public byte Type { get; set; }
        public ArraySegment<byte> Buffer { get; set; }
        public int Size { get; set; }
        public int AssetId { get; set; }
        public int? CheckSum { get; set; }

        protected override void DeserializeNow(ArraySegment<byte> data)
        {
            throw new NotImplementedException();
        }
        protected override int SerializeNow(ArraySegment<byte> data)
        {
            data[0] = (byte)(AssetId != 0 ? (CheckSum.HasValue ? 2 : 1) : 0);
            data[1] = Type;
            if (AssetId != 0)
            {
                PutInt(data, 2, Size);
                PutInt(data, 6, AssetId);
                if (CheckSum.HasValue)
                {
                    PutInt(data, 10, CheckSum.Value);
                    return 14;
                }
                return 10;
            }
            else
                return 2;
        }
    }
}