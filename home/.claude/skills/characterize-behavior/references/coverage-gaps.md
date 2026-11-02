# Coverage gaps

Code the usual loop cannot pin: code that reaches outside past the framework, and code no entry point reaches. Both still count towards the 100 % gate.

## Code without a seam

Code that reaches an external system past the framework (a direct HTTP client, `curl_*`, a URL opened as a file, a socket, an SDK with its own connection) cannot be faked from outside, and a test that runs it would contact that system. Do not run it. Pin every path of the same class that does not reach that call. Exclude the file from coverage under `<source><exclude>` in `phpunit.xml`, one `<file>` with an XML comment naming the call, so the gate measures what can be measured, and record the file, the call, and the untested paths as a finding: making them testable needs a change to application code, which is a decision for people.

## Code without an entry point

Code without an entry point (a controller action no route uses, a class nothing references) is still behaviour: pin it with a unit test through its public interface, for example by calling the action and asserting the view or response it returns, and record the missing entry point as a finding. Only code that cannot run at all, even when called directly (for example because it needs an extension or service the test environment cannot provide), may be excluded under `<source><exclude>` in `phpunit.xml`, one `<file>` per file with an XML comment giving the reason, and listed in the report. Never hide lines from coverage in application code. The test style reference shows the shape of such a test.
