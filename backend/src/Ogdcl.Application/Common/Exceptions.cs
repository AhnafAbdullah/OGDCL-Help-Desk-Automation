namespace Ogdcl.Application.Common;

/// <summary>Mapped to HTTP 404 by the API exception middleware.</summary>
public class NotFoundException : Exception
{
    public NotFoundException(string message) : base(message) { }
}

/// <summary>Mapped to HTTP 400.</summary>
public class AppValidationException : Exception
{
    public AppValidationException(string message) : base(message) { }
}

/// <summary>Mapped to HTTP 403.</summary>
public class ForbiddenException : Exception
{
    public ForbiddenException(string message) : base(message) { }
}

/// <summary>Mapped to HTTP 401.</summary>
public class UnauthorizedException : Exception
{
    public UnauthorizedException(string message) : base(message) { }
}
