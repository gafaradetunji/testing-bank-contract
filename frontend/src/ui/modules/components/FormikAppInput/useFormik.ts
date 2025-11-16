"use client"

import { useField } from "formik"
import { ChangeEvent } from "react"

export interface UseFormikShadcnInputReturn {
  field: any
  handleChange: (e: ChangeEvent<HTMLInputElement | HTMLTextAreaElement>) => void
  hasError: boolean
  errorMessage: string | undefined
  meta: any
  isSuccess: boolean
}

export const useFormikShadcnInput = ({
  validateBeforeTouch,
  ...props
}: {
  name: string
  validateBeforeTouch?: boolean
  onChange?: (e: ChangeEvent<any>) => void
}): UseFormikShadcnInputReturn => {
  const [field, meta] = useField(props.name)

  const handleChange = (e: ChangeEvent<HTMLInputElement | HTMLTextAreaElement>) => {
    props.onChange?.(e)
    field.onChange(e)
  }

  const hasError = !!((validateBeforeTouch || meta.touched) && meta.error)
  const errorMessage =
    (validateBeforeTouch || meta.touched) && meta.error ? meta.error : undefined

  const isSuccess = meta.touched && !meta.error && !!field.value

  return {
    field,
    meta,
    handleChange,
    hasError,
    errorMessage,
    isSuccess,
  }
}
