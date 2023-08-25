using System;
using System.Collections.Generic;
using System.Threading.Tasks;

namespace NabuNet
{
    // a very generic database abstraction. Should be easy enough to map to SQL, Tables, or just the filesystem.
    public interface IDatabase
    {
        Task<T?> GetDocumentAsync<T>(string documentName, string key) where T : class, IKeyRecord;
        Task<T> GetRequiredDocumentAsync<T>(string documentName, string key) where T : class, IKeyRecord;
        Task SetDocumentAsync<T>(string documentName, T content) where T : class, IKeyRecord;
        Task RemoveDocumentAsync(string documentName, string key);

        Task<bool> DocumentExists(string documentName, string key);


        Task<T?> GetSingleDocumentAsync<T>(string documentName) where T : class;
        Task<T> GetSingleRequiredDocumentAsync<T>(string documentName) where T : class, new();
        Task SetSingleDocumentAsync<T>(string documentName, T content) where T : class;
        Task FlushAsync();
        Task RemoveSingleDocumentAsync(string documentName);
        Task<bool> SingleDocumentExists(string documentName);
        Task<IEnumerable<string>> GetDocumentListAsync(string documentName);
    }
}