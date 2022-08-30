BeforeAll {
    . $PSScriptRoot/../ImageCache.ps1

    # Suppress logging
    Mock WriteLogMessage {}

    # Mock temp local storage
    function SaveLocally () {}
    Mock SaveLocally {}

    # Mock the internet
    $test_response_size = 1024
    Mock Invoke-WebRequest {
        return New-MockObject -Type "Microsoft.PowerShell.Commands.WebResponseObject" `
                                -Properties @{RawContentLength = $test_response_size;
                                              RawContentStream = (New-MockObject -Type object -Methods @{ CopyTo = { SaveLocally } })}
    }
}


Describe "ImageCacheTests" {
    Context "StatelessImageCacheTests" {
        BeforeDiscovery {
            $test_size = $test_response_size
        }

        BeforeEach {
            [ImageCache]::Reset()
        }

        It "RespectsMaximumResponseSize" -TestCases @(
            @{MaxSize = $test_size; ExpectedSave = $true},
            @{MaxSize = $test_size - 1; ExpectedSave = $false}
        ) {
            [ImageCache]::FetchImage("http://example.com/foo.jpg", "", $maxSize)
            if ($expectedSave) {
                Should -Invoke -CommandName SaveLocally -Times 1 -Exactly
            } else {
                Should -Not -Invoke -CommandName SaveLocally
            }
        }
    }

    Context "ImageCacheRetentionTests" {
        BeforeAll {
            [ImageCache]::Reset()
        }

        It "SuccessfulDownloadIsRetained" {
            $paths = @( (1..5) | % { [ImageCache]::FetchImage("http://example.com/foo.jpg", "", $test_response_size) } )
            Should -Invoke -CommandName Invoke-WebRequest -Times 1 -Exactly
            Should -Invoke -CommandName SaveLocally -Times 1 -Exactly
            $paths | Should -BeExactly @($paths[0..0] * 5)
        }
    }

    Context "ImageCacheRetryTests" {
        BeforeAll {
            $max_attempts = 4
            [ImageCache]::Reset()
            [ImageCache]::MaximumAttempts = $max_attempts
            Mock Invoke-WebRequest {throw "Simulated web failure"}
        }

        It "DownloadIsRetriedUpToMax" {
            (1..($max_attempts+2)) | % { [ImageCache]::FetchImage("http://example.com/foo.jpg", "", $test_response_size) }
            Should -Invoke -CommandName Invoke-WebRequest -Times $max_attempts -Exactly
            Should -Not -Invoke -CommandName SaveLocally
        }
    }
}