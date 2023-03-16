import { useEffect, useRef } from "react"

export const Canvas = ({
  pixels,
  ...restProps
}: {
  pixels: Uint8Array
} & React.DetailedHTMLProps<React.CanvasHTMLAttributes<HTMLCanvasElement>, HTMLCanvasElement>) => {
  const canvasRef = useRef<HTMLCanvasElement>(null)

  useEffect(() => {
    const canvas = canvasRef.current!
    const ctx = canvas.getContext("2d")!

    const imageData = ctx.getImageData(0, 0, 640, 384)
    imageData.data.set(pixels)

    ctx.putImageData(imageData, 0, 0)
  }, [pixels])

  return <canvas ref={canvasRef} {...restProps} />
}
