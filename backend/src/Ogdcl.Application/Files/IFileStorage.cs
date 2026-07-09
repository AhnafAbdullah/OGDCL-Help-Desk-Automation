namespace Ogdcl.Application.Files;

public interface IFileStorage
{
    /// <summary>Saves the stream and returns the stored relative path.</summary>
    Task<string> SaveAsync(string directory, string fileName, Stream content, CancellationToken ct = default);

    Stream OpenRead(string storedPath);
}
