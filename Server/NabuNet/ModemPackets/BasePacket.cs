using System;

namespace NabuNet.ModemPacktes
{
    // A base class for modem input/output packet serialization.
    // The Nabu Modem code runs in minimal environment and needs
    // essentially binary data to perform optimal; to ensure
    // byte-by-byte accuracy, the packets use a custom serialization
    // logic to hop on and off the wire.
    public abstract class BasePacket
    {
        private readonly byte _Marker;

        protected BasePacket(byte marker)
        {
            _Marker = marker;
        }

        public static T Deserialize<T>(ArraySegment<byte> input) where T : BasePacket, new()
        {
            T result = new T();

            if (result._Marker != input[0])
                throw new InvalidOperationException($"Marker byte doesn't match expected value. Got {input[0]}, expected {result._Marker}");

            result.DeserializeNow(input.Slice(1));

            return result;
        }

        protected static string ExtractString(ArraySegment<byte> source, int offset, out int postStringOffset)
        {
            int len = source[offset];
            postStringOffset = offset + len + 1;
            return System.Text.Encoding.ASCII.GetString(source.AsSpan(offset + 1, len));
        }

        protected static int PutString(ArraySegment<byte> target, int offset, string value, int maxLength = 127)
        {
            var b = System.Text.Encoding.ASCII.GetBytes(value);
            if (b.Length > maxLength || maxLength > 127)
                throw new InvalidOperationException($"Maximum string length {maxLength} or 127 exceeded: {b.Length}");
            target[offset] = (byte)b.Length;
            b.CopyTo(target.AsSpan(offset + 1, b.Length));
            return offset + 1 + b.Length;
        }

        public int Serialize(ArraySegment<byte> target)
        {
            target[0] = _Marker;
            return SerializeNow(target.Slice(1)) + 1;
        }

        protected int PutBoolean(ArraySegment<byte> data, int offset, bool value)
        {
            data[offset] = (byte)(value ? 1 : 0);
            return offset + 1;
        }

        protected int PutInt(ArraySegment<byte> data, int offset, int value)
        {
            data[offset + 3] = (byte)((value >> 24) & 0xFF);
            data[offset + 2] = (byte)((value >> 16) & 0xFF);
            data[offset + 1] = (byte)((value >> 8) & 0xFF);
            data[offset] = (byte)(value & 0xFF);
            return offset + 4;
        }

        protected int ExtractInt(ArraySegment<byte> data, int offset)
        {
            int value = data[offset + 3];
            value = value << 8 | data[offset + 2];
            value = value << 8 | data[offset + 1];
            value = value << 8 | data[offset];
            return value;
        }

        protected int ExtractWord(ArraySegment<byte> data, int offset)
        {
            return data[offset] | (((int)data[offset + 1]) << 8);
        }
        protected void PutWord(ArraySegment<byte> data, int offset, int value)
        {
            data[offset] = (byte)(value & 0xFF);
            data[offset + 1] = (byte)((value >> 8) & 0xFF);
        }


        protected abstract int SerializeNow(ArraySegment<byte> data);
        protected abstract void DeserializeNow(ArraySegment<byte> data);
    }
}