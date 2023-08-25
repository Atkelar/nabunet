using System;
using System.Threading.Tasks;
using Microsoft.Extensions.Caching.Memory;

namespace NabuNet
{
    public class MomoryCacheImplementation
        : ICache
    {
        private readonly IMemoryCache _BaseCache;
        private static readonly MemoryCacheEntryOptions _Options = new MemoryCacheEntryOptions() { SlidingExpiration = TimeSpan.FromMinutes(20) };

        public MomoryCacheImplementation(IMemoryCache baseCache)
        {
            _BaseCache = baseCache;
        }
        public async Task<T> GetCachedVersion<T>(string type, string key, Func<string, Task<T>> loader)
        {
            string cKey = $"{type}-{key}";
            T result;
            if (_BaseCache.TryGetValue<T>(cKey, out result))
                return result;
            result = await loader(key);
            _BaseCache.Set<T>(cKey, result, _Options);
            return result;
        }

        public async Task RemoveCachedVersion(string type, string key)
        {
            string cKey = $"{type}-{key}";
            _BaseCache.Remove(cKey);
        }

        public async Task UpdateCachedVersion<T>(string type, string key, T value)
        {
            string cKey = $"{type}-{key}";
            _BaseCache.Set<T>(cKey, value, _Options);
        }
    }
}