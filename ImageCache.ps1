class ImageCache {
    static [hashtable]$PathMap = @{}
    static [hashtable]$BadUris = @{}
    static [int]$DefaultMaxSizeInBytes = 256000
    static [int]$MaximumAttempts = 3


    static [void]Reset () {
        [ImageCache]::PathMap = @{}
        [ImageCache]::BadUris = @{}
    }

    static [string]StoreResponseData ([object]$response) {
        $file_stream = $null
        try {
            $local_file = New-TemporaryFile
            $local_file_path = $local_file.FullName
            $file_stream = New-Object IO.FileStream($local_file, "Append", "Write", "Read")
            $response.RawContentStream.CopyTo($file_stream)
            WriteLogMessage "Saved to $local_file_path"
            return $local_file_path
        } finally {
            if ($file_stream) {
                $file_stream.Close()
            }
        }
    }

    static [string]FetchImage ([string]$uri, [string]$log_file_path, [nullable[int]]$max_size_bytes) {
        if ([ImageCache]::PathMap.ContainsKey($uri)) {
            $local_path = [ImageCache]::PathMap[$uri]
            if (Test-Path $local_path) {
                WriteLogMessage "Using already downloaded image from $uri" $log_file_path
                return $local_path
            }
        }
        if ([ImageCache]::BadUris.ContainsKey($uri)) {
            $failures = [ImageCache]::BadUris[$uri]
            if (([ImageCache]::MaximumAttempts -gt 0) -and $failures -ge [ImageCache]::MaximumAttempts) {
                WriteLogMessage "Not retrying ($failures previous failures): $uri" $log_file_path
                return ""
            } elseif ($failures -eq -1) {
                WriteLogMessage "Not retrying (too large): $uri" $log_file_path
                return ""
            }
        }

        if ($null -eq $max_size_bytes) {
            $max_size_bytes = [ImageCache]::DefaultMaxSizeInBytes
        }
        $ret = ""
        try {
            $response = Invoke-WebRequest -Uri $uri
            $response_size = $response.RawContentLength
            WriteLogMessage "Downloaded image ($response_size bytes) from $uri" $log_file_path
            if ($response_size -gt $max_size_bytes) {
                [ImageCache]::BadUris[$uri] = -1
                WriteLogMessage "Image too large: not saving"
            } else {
                $local_file_path = [ImageCache]::StoreResponseData($response)
                [ImageCache]::PathMap[$uri] = $local_file_path
                $ret = $local_file_path
            }
        } catch {
            WriteLogMessage "Exception fetching image from $uri" $log_file_path
            WriteLogMessage $_ $log_file_path
            [ImageCache]::BadUris[$uri] = if ([ImageCache]::BadUris.ContainsKey($uri)) {[ImageCache]::BadUris[$uri] + 1} else {1}
        }
        return $ret
    }
}
