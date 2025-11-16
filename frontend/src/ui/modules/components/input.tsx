import * as React from "react"
import { Loader2Icon, CheckIcon } from "lucide-react"
import { cn } from "@/src/common"

function Input({
  className,
  type,
  isLoading = false,
  isSuccess = false,
  disabled,
  ...props
}: React.ComponentProps<"input"> & {
  isLoading?: boolean
  isSuccess?: boolean
}) {
  return (
    <div className="relative w-full flex items-center justify-between">
      <input
        type={type}
        data-slot="input"
        disabled={isLoading || disabled}
        className={cn(
          "file:text-foreground placeholder:text-muted-foreground selection:bg-primary selection:text-primary-foreground dark:bg-input/30 border-input h-9 w-full min-w-0 rounded-md border bg-transparent px-3 py-1 text-base shadow-xs transition-[color,box-shadow] outline-none file:inline-flex file:h-7 file:border-0 file:bg-transparent file:text-sm file:font-medium disabled:pointer-events-none disabled:cursor-not-allowed disabled:opacity-50 md:text-sm",
          "focus-visible:border-ring focus-visible:ring-ring/50 focus-visible:ring-[3px]",
          "aria-invalid:ring-destructive/20 dark:aria-invalid:ring-destructive/40 aria-invalid:border-destructive",
          (isLoading || isSuccess) && "pr-9",
          className
        )}
        {...props}
      />

      {isLoading && (
        <Loader2Icon
          role="status"
          aria-label="Loading"
          className="absolute right-2 top-1/2 size-4 -translate-y-1/2 animate-spin text-muted-foreground"
        />
      )}

      {!isLoading && isSuccess && (
        <CheckIcon
          aria-label="Success"
          className="absolute right-2 top-1/2 size-4 -translate-y-1/2 text-green-500"
        />
      )}
    </div>
  )
}

export { Input }