using System;
using System.Threading.Tasks;

namespace NabuNet
{
    public interface ICache
    {
        public Task<T> GetCachedVersion<T>(string type, string key, Func<string, Task<T>> loader);

        public Task UpdateCachedVersion<T>(string type, string key, T value);

        public Task RemoveCachedVersion(string type, string key);

    }
}