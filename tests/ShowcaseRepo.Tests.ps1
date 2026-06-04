#Requires -Version 5.1
<#
  ShowcaseRepo.Tests.ps1 - repository-level checks for the public showcase.
  These tests keep the runnable demo, docs entry point and proof references tidy.
#>

Describe 'Showcase repository packaging' {
    BeforeAll {
        $root = Resolve-Path (Join-Path $PSScriptRoot '..')
    }

    It 'keeps the GitHub Pages demo in sync with the browser demo' {
        $demo = Get-Content -Raw -Path (Join-Path $root 'demo/demo.html')
        $docs = Get-Content -Raw -Path (Join-Path $root 'docs/index.html')
        $docs | Should -Be $demo
    }

    It 'documents the clean-room proof commands in the README' {
        $readme = Get-Content -Raw -Path (Join-Path $root 'README.md')
        $readme | Should -Match 'Run-Demo\.ps1'
        $readme | Should -Match 'Invoke-Pester'
        $readme | Should -Match 'docs/EVIDENCE\.md'
    }

    It 'keeps the public evidence map in the repo' {
        Join-Path $root 'docs/EVIDENCE.md' | Should -Exist
        Join-Path $root 'demo/agent/README.md' | Should -Exist
    }

    It 'includes a non-empty dashboard screenshot for the README' {
        $screenshot = Get-Item -Path (Join-Path $root 'docs/dashboard.png')
        $screenshot.Length | Should -BeGreaterThan 50000
    }
}
