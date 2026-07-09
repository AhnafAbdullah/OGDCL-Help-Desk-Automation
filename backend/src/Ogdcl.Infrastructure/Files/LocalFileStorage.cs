using Ogdcl.Application.Files;

namespace Ogdcl.Infrastructure.Files;

/// <summary>
/// Stores attachments on the local filesystem (a Docker volume in deployment).
/// Files are renamed to GUIDs so uploaded names can never traverse paths.
/// </summary>
public class LocalFileStorage : IFileStorage
{
    private readonly string _root;

    public LocalFileStorage(string root)
    {
        _root = Path.GetFullPath(root);
        Directory.CreateDirectory(_root);
    }

    public async Task<string> SaveAsync(string directory, string fileName, Stream content, CancellationToken ct = default)
    {
        var safeName = $"{Guid.NewGuid():N}{Path.GetExtension(fileName).ToLowerInvariant()}";
        var relative = Path.Combine(directory, safeName);
        var full = ResolveSafe(relative);

        Directory.CreateDirectory(Path.GetDirectoryName(full)!);
        await using var file = File.Create(full);
        await content.CopyToAsync(file, ct);

        return relative.Replace('\\', '/');
    }

    public Stream OpenRead(string storedPath) => File.OpenRead(ResolveSafe(storedPath));

    private string ResolveSafe(string relative)
    {
        var full = Path.GetFullPath(Path.Combine(_root, relative));
        if (!full.StartsWith(_root, StringComparison.OrdinalIgnoreCase))
            throw new InvalidOperationException("Invalid storage path.");
        return full;
    }
}
